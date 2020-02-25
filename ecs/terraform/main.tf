terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket  = "odin-infra-dev"
    key     = "infrastructure/sitecore-ecs"
    region  = "eu-central-1"
    profile = "nuuday_digital_dev"
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "nuuday_digital_dev"
  version = "2.45"
}

data "aws_region" "current" {}

locals {
  cluster_name = "asore-sc-dev"

  internal_cidr_blocks = [
    "83.92.190.99/32",
    "193.3.142.51/32",
    "213.32.242.209/32",
  ]

  common_tags = {
    Team    = "odin-platform"
    billing = "odin-platform"
    Author  = "asore"
  }
}

# IAM resources necessary to allow Sitecore ECS tasks to
# retrieve connection strings from AWS Secrets Manager

# An AWS-managed policy which allows ECR and CloudWatch access
data "aws_iam_policy" "managed_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Explicitly allows access to retrieve connection strings from Secrets Manager,
# and accessing the encryption key we're using.
data "aws_iam_policy_document" "connection_string_secrets" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]

    resources = [
      aws_secretsmanager_secret.core_connection_string.arn,
      aws_secretsmanager_secret.master_connection_string.arn,
      aws_secretsmanager_secret.web_connection_string.arn,
      aws_secretsmanager_secret.security_connection_string.arn,
      aws_secretsmanager_secret.forms_connection_string.arn,
      aws_secretsmanager_secret.sessions_connection_string.arn,
      aws_kms_key.db.arn,
    ]
  }
}

resource "aws_iam_policy" "connection_string_secrets" {
  name        = "SitecoreConnectionStringsReadAccess"
  path        = "/odin/"
  description = "Allows retrieval of connection string secrets for Sitecore"
  policy      = data.aws_iam_policy_document.connection_string_secrets.json
}

data "aws_iam_policy_document" "assume_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution_role" {
  name = "SitecoreEcsTaskExecutionRole"
  path = "/odin/"

  assume_role_policy = data.aws_iam_policy_document.assume_policy.json
}

resource "aws_iam_role_policy_attachment" "task_execution_role_secrets" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.connection_string_secrets.arn
}

resource "aws_iam_role_policy_attachment" "task_execution_role_builtin" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = data.aws_iam_policy.managed_execution_policy.arn
}

# Networking

module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v2.21.0"

  name = local.cluster_name

  cidr = "10.1.0.0/16"

  azs              = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets   = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
  database_subnets = ["10.1.20.0/24", "10.1.21.0/24", "10.1.22.0/24"]

  # In a production setting we'd deploy a NAT gateway per AZ.
  # We use a single one in this example to reduce the number of
  # Elastic IP Addresses we consume in AWS.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # Required to access DB from outside the VPC
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

data "aws_ami" "windows_ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Core-ECS_Optimized-*"]
  }
}

resource "aws_iam_policy" "instance_role_cloudwatch" {
  name        = "ECS-CloudWatchLogs"
  path        = "/ecs/"
  description = "Allows creation of LogStreams and LogGroups in CloudWatch"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        }
    ]
}
EOF
}

data "aws_iam_role" "ecs_instance" {
  name = "ecsInstanceRole"
}

resource "aws_iam_role_policy_attachment" "instance_role_cloudwatch" {
  role       = data.aws_iam_role.ecs_instance.id
  policy_arn = aws_iam_policy.instance_role_cloudwatch.arn
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  tags = local.common_tags
}

data "template_file" "user_data_windows" {
  template = file("${path.module}/templates/ec2-user-data-ecs-windows.script")
  vars = {
    cluster_name = local.cluster_name
  }
}

resource "aws_security_group" "allow_all_internal" {
  name   = "allow_all_internal"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = local.internal_cidr_blocks
  }
}

resource "aws_security_group" "ecs_instances" {
  name   = "ecs_instances"
  vpc_id = module.vpc.vpc_id

  # LB health checks
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    security_groups = [aws_security_group.lb_external.id]
  }
}

module "ecs_instances" {
  source = "github.com/terraform-aws-modules/terraform-aws-autoscaling?ref=v3.4.0"

  name          = "${local.cluster_name}-asg"
  image_id      = data.aws_ami.windows_ecs.image_id
  instance_type = var.ec2_instance_type

  security_groups = [
    module.vpc.default_security_group_id,
    aws_security_group.ecs_instances.id,
  ]

  asg_name             = "${local.cluster_name}-asg"
  vpc_zone_identifier  = module.vpc.private_subnets
  health_check_type    = "EC2"
  min_size             = var.ecs_instance_count
  max_size             = var.ecs_instance_count
  desired_capacity     = var.ecs_instance_count
  iam_instance_profile = data.aws_iam_role.ecs_instance.id
  key_name             = "ASORE"

  user_data = data.template_file.user_data_windows.rendered

  tags_as_map = local.common_tags
}

# Ingress

resource "aws_security_group" "lb_external" {
  name   = "${local.cluster_name}-lb-external-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = concat(
      local.internal_cidr_blocks,
      [for ip in module.vpc.nat_public_ips : "${ip}/32"]
    )
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = concat(
      local.internal_cidr_blocks,
      [for ip in module.vpc.nat_public_ips : "${ip}/32"]
    )
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_lb_target_group" "default" {
  name     = "${local.cluster_name}-instance-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

# Self-signed cert for default LB listener
resource "tls_private_key" "default" {
  algorithm = "ECDSA"
}

resource "tls_self_signed_cert" "default" {
  key_algorithm   = tls_private_key.default.algorithm
  private_key_pem = tls_private_key.default.private_key_pem

  validity_period_hours = 24 * 365 * 100

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [aws_lb.lb_external.dns_name]

  subject {
    common_name  = aws_lb.lb_external.dns_name
    organization = "GEN"
  }
}

resource "aws_iam_server_certificate" "default" {
  certificate_body = tls_self_signed_cert.default.cert_pem
  private_key      = tls_private_key.default.private_key_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "lb_external" {
  name            = "${local.cluster_name}-lb"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.lb_external.id]

  tags = local.common_tags
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.lb_external.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.lb_external.id
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn = aws_iam_server_certificate.default.arn

  default_action {
    target_group_arn = aws_lb_target_group.default.id
    type             = "forward"
  }
}

resource "aws_cloudwatch_log_group" "sitecore" {
  name              = "sitecore"
  retention_in_days = 1

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "cd" {
  name              = "cd"
  retention_in_days = 1

  tags = {
    Application = "CD"
  }
}

# Database

resource "aws_security_group" "db" {
  name   = "allow_db"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 1433
    to_port   = 1433
    protocol  = "tcp"

    security_groups = [aws_security_group.ecs_instances.id]
  }
}

resource "random_string" "db_password" {
  length           = 16
  special          = true
  override_special = "!"
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
}

resource "aws_kms_key" "db" {
  description = "Sitecore 9 DB at-rest-encryption"
  is_enabled  = true

  tags = local.common_tags
}

module "rds" {
  source = "github.com/terraform-aws-modules/terraform-aws-rds?ref=v2.13.0"

  identifier = "${local.cluster_name}-db"

  family               = "sqlserver-web-14.0"
  engine               = "sqlserver-web"
  engine_version       = "14.00.3223.3.v1"
  major_engine_version = "14.00"
  timezone             = "Central Standard Time"
  instance_class       = "db.m5.large"
  allocated_storage    = 20
  license_model        = "license-included"
  ca_cert_identifier   = "rds-ca-2019"

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  name     = null # see 'identifier'
  username = "dbuser"
  password = random_string.db_password.result
  port     = "1433"

  # Encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.db.arn

  multi_az            = false
  publicly_accessible = true
  subnet_ids          = module.vpc.database_subnets
  vpc_security_group_ids = [
    aws_security_group.allow_all_internal.id,
    aws_security_group.db.id,
  ]

  tags = local.common_tags
}

# Connection string secrets

# Security DB
resource "aws_secretsmanager_secret" "security_connection_string" {
  name_prefix = "asore_security_connection_string_"
  kms_key_id  = aws_kms_key.db.arn
}

resource "aws_secretsmanager_secret_version" "security_connection_string" {
  secret_id     = aws_secretsmanager_secret.security_connection_string.id
  secret_string = "Server=${module.rds.this_db_instance_address};User=${module.rds.this_db_instance_username};Password=${module.rds.this_db_instance_password};Database=Sitecore.Core"
}

# Core DB
resource "aws_secretsmanager_secret" "core_connection_string" {
  name_prefix = "asore_core_connection_string_"
  kms_key_id  = aws_kms_key.db.arn
}

resource "aws_secretsmanager_secret_version" "core_connection_string" {
  secret_id     = aws_secretsmanager_secret.core_connection_string.id
  secret_string = "Server=${module.rds.this_db_instance_address};User=${module.rds.this_db_instance_username};Password=${module.rds.this_db_instance_password};Database=Sitecore.Core"
}

# Master DB
resource "aws_secretsmanager_secret" "master_connection_string" {
  name_prefix = "asore_master_connection_string_"
  kms_key_id  = aws_kms_key.db.arn
}

resource "aws_secretsmanager_secret_version" "master_connection_string" {
  secret_id     = aws_secretsmanager_secret.master_connection_string.id
  secret_string = "Server=${module.rds.this_db_instance_address};User=${module.rds.this_db_instance_username};Password=${module.rds.this_db_instance_password};Database=Sitecore.Master"
}

# Master DB
resource "aws_secretsmanager_secret" "web_connection_string" {
  name_prefix = "asore_web_connection_string_"
  kms_key_id  = aws_kms_key.db.arn
}

resource "aws_secretsmanager_secret_version" "web_connection_string" {
  secret_id     = aws_secretsmanager_secret.web_connection_string.id
  secret_string = "Server=${module.rds.this_db_instance_address};User=${module.rds.this_db_instance_username};Password=${module.rds.this_db_instance_password};Database=Sitecore.Web"
}

# Forms Experience DB
resource "aws_secretsmanager_secret" "forms_connection_string" {
  name_prefix = "asore_forms_connection_string_"
  kms_key_id  = aws_kms_key.db.arn
}

resource "aws_secretsmanager_secret_version" "forms_connection_string" {
  secret_id     = aws_secretsmanager_secret.forms_connection_string.id
  secret_string = "Server=${module.rds.this_db_instance_address};User=${module.rds.this_db_instance_username};Password=${module.rds.this_db_instance_password};Database=Sitecore.Experienceforms"
}

# Sessions DB
resource "aws_secretsmanager_secret" "sessions_connection_string" {
  name_prefix = "asore_sessions_connection_string_"
  kms_key_id  = aws_kms_key.db.arn
}

resource "aws_secretsmanager_secret_version" "sessions_connection_string" {
  secret_id     = aws_secretsmanager_secret.sessions_connection_string.id
  secret_string = "Server=${module.rds.this_db_instance_address};User=${module.rds.this_db_instance_username};Password=${module.rds.this_db_instance_password};Database=Sitecore.Sessions"
}

