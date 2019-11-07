terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket = "odin-infra-dev"
    key    = "infrastructure/sitecore-ecs"
    region = "eu-central-1"
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "nuuday_digital_dev"
}

locals {
  cluster_name = "sitecore-dev"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = local.cluster_name

  cidr = "10.1.0.0/16"

  azs              = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets   = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
  database_subnets = ["10.1.20.0/24", "10.1.21.0/24", "10.1.22.0/24"]

  enable_nat_gateway = true

  # Required to access DB from outside the VPC
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Team = "odin-platform"
  }
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

module "cluster" {
  source = "github.com/terraform-aws-modules/terraform-aws-ecs?ref=v2.0.0"

  name = local.cluster_name
  tags = {
    Team = "odin-platform"
  }
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

    cidr_blocks = [
      "128.76.39.70/32",
      "193.3.142.51/32",
    ]
  }
}

resource "aws_security_group" "allow_lb_ingress" {
  name   = "allow_lb_ingress"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"

    security_groups = [aws_security_group.lb_external.id]
  }
}

resource "aws_security_group" "ecs_instances" {
  name   = "ecs_instances"
  vpc_id = module.vpc.vpc_id
}

module "ecs_instances" {
  source = "github.com/terraform-aws-modules/terraform-aws-autoscaling?ref=v3.1.0"

  name          = "${local.cluster_name}-asg"
  image_id      = data.aws_ami.windows_ecs.image_id
  instance_type = var.ec2_instance_type

  security_groups = [
    module.vpc.default_security_group_id,
    aws_security_group.ecs_instances.id,
    aws_security_group.allow_lb_ingress.id,
    aws_security_group.allow_all_internal.id
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

  tags = [
    {
      key                 = "Team"
      value               = "odin-platform",
      propagate_at_launch = true
    }
  ]
}

# Ingress

resource "aws_security_group" "lb_external" {
  name   = "${local.cluster_name}-lb-external-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

  validity_period_hours = 356 * 24

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
  name             = "${local.cluster_name}-ecs-default-cert"
  certificate_body = tls_self_signed_cert.default.cert_pem
  private_key      = tls_private_key.default.private_key_pem
}

resource "aws_lb" "lb_external" {
  name            = "${local.cluster_name}-lb"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.lb_external.id]
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

  certificate_arn = aws_iam_server_certificate.default.arn

  default_action {
    target_group_arn = aws_lb_target_group.default.id
    type             = "forward"
  }
}

module "service" {
  source = "./modules/service"

  name                       = "aspnet-sample"
  ecs_cluster_id             = module.cluster.this_ecs_cluster_id
  vpc_id                     = module.vpc.vpc_id
  route53_zone_name          = "aws.nuuday.nu."
  dns_prefix                 = "iis-sample-dev"
  container_definitions_json = file("${path.module}/definitions/iis-sample.json")
  lb_arn                     = aws_lb.lb_external.id
  lb_listener_arn            = aws_lb_listener.frontend.id
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
  length = 16
}

module "rds" {
  source = "github.com/terraform-aws-modules/terraform-aws-rds?ref=v2.5.0"

  identifier = "${local.cluster_name}-db"

  family               = "sqlserver-web-14.0"
  engine               = "sqlserver-web"
  engine_version       = "14.00.3192.2.v1"
  major_engine_version = "14.00"
  timezone             = "Central Standard Time"
  instance_class       = "db.m5.large"
  allocated_storage    = 20
  license_model        = "license-included"

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  name     = null # see 'identifier'
  username = "dbuser"
  password = random_string.db_password.result
  port     = "1433"

  multi_az            = false
  publicly_accessible = true
  subnet_ids          = module.vpc.database_subnets
  vpc_security_group_ids = [
    aws_security_group.allow_all_internal.id,
    aws_security_group.db.id,
  ]

  tags = {
    Team = "odin-platform"
  }
}

