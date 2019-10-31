terraform {
  required_version = ">= 0.12"
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

resource "aws_ecs_task_definition" "iis" {
  family = "iis"
  #task_role_arn = "${data.aws_iam_role.ecs_service_role.arn}"
  #execution_role_arn = "${data.aws_iam_role.ecs_service_role.arn}"

  container_definitions = <<EOF
[
	{
		"name": "iis",
    "image": "mcr.microsoft.com/dotnet/framework/samples:aspnetapp",
    "cpu": 512,
    "memory": 2048,
    "entryPoint": ["powershell", "-Command"],
    "command": ["c:\\ServiceMonitor.exe w3svc"],
		"portMappings": [
			{
				"containerPort": 80
			}
		]
	}
]
EOF
}

module "cluster" {
  source = "github.com/terraform-aws-modules/terraform-aws-ecs?ref=v2.0.0"

  name = local.cluster_name
  tags = {
    Team = "odin-platform"
  }
}

resource "aws_ecs_service" "iis_sample" {
  name                               = "iis_sample"
  cluster                            = module.cluster.this_ecs_cluster_id
  launch_type                        = "EC2"
  task_definition                    = aws_ecs_task_definition.iis.arn
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 120

  depends_on = [aws_lb.lb_external]

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_instances.id
    container_name   = "iis"
    container_port   = 80
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  desired_count = 1
}

# CD
resource "aws_ecs_task_definition" "cd" {
  family = "cd"

  container_definitions = <<EOF
[
	{
		"name": "cd",
    "image": "anarsdk/sitecore-cd:9.2.0-attempt1",
    "cpu": 512,
    "memory": 2048,
		"portMappings": [
			{
				"containerPort": 80
			}
		]
	}
]
EOF
}

resource "aws_ecs_service" "cd" {
  name                               = "cd"
  cluster                            = module.cluster.this_ecs_cluster_id
  launch_type                        = "EC2"
  task_definition                    = aws_ecs_task_definition.cd.arn
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 120

  depends_on = [aws_lb.lb_external]

  load_balancer {
    target_group_arn = aws_lb_target_group.cd.id
    container_name   = "cd"
    container_port   = 80
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  desired_count = 1
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

    cidr_blocks = ["128.76.39.70/32"]
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
  instance_type = "t3.large"
  security_groups = [
    module.vpc.default_security_group_id,
    aws_security_group.ecs_instances.id,
    aws_security_group.allow_lb_ingress.id,
    aws_security_group.allow_all_internal.id
  ]

  asg_name             = "${local.cluster_name}-asg"
  vpc_zone_identifier  = module.vpc.public_subnets
  health_check_type    = "EC2"
  min_size             = 2
  max_size             = 2
  desired_capacity     = 2
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

resource "aws_lb_target_group" "ecs_instances" {
  name     = "${local.cluster_name}-instance-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_target_group" "cd" {
  name     = "${local.cluster_name}-cd-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_listener_rule" "cd" {
  listener_arn = aws_lb_listener.frontend.arn

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cd.arn
  }

  condition {
    field = "host-header"
    values = [aws_route53_record.cd.fqdn]
  }
}

resource "aws_lb" "lb_external" {
  name            = "${local.cluster_name}-lb"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.lb_external.id]
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.lb_external.id
  port              = 443
  protocol          = "HTTPS"

  certificate_arn = aws_acm_certificate_validation.iis_sample.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.ecs_instances.id
    type             = "forward"
  }
}

resource "aws_lb_listener_certificate" "cd" {
  listener_arn = aws_lb_listener.frontend.arn
  certificate_arn = aws_acm_certificate_validation.cd.certificate_arn
}

data "aws_route53_zone" "nuuday" {
  name         = "aws.nuuday.nu."
  private_zone = false
}

resource "aws_route53_record" "iis_sample" {
  zone_id = data.aws_route53_zone.nuuday.id
  name    = "iis-sample-dev.${data.aws_route53_zone.nuuday.name}"
  type    = "CNAME"
  ttl     = "300"

  records = [aws_lb.lb_external.dns_name]
}

resource "aws_route53_record" "cd" {
  zone_id = data.aws_route53_zone.nuuday.id
  name    = "cd-dev.${data.aws_route53_zone.nuuday.name}"
  type    = "CNAME"
  ttl     = "300"

  records = [aws_lb.lb_external.dns_name]
}


# Certificate: IIS
resource "aws_route53_record" "iis_cert_validation" {
  zone_id = data.aws_route53_zone.nuuday.id
  name    = aws_acm_certificate.iis_sample.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.iis_sample.domain_validation_options.0.resource_record_type
  ttl     = "60"

  records = [aws_acm_certificate.iis_sample.domain_validation_options.0.resource_record_value]
}

resource "aws_acm_certificate" "iis_sample" {
  domain_name       = aws_route53_record.iis_sample.fqdn
  validation_method = "DNS"

  tags = {
    Team = "odin-platform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "iis_sample" {
  certificate_arn         = aws_acm_certificate.iis_sample.arn
  validation_record_fqdns = [aws_route53_record.iis_cert_validation.fqdn]
}

# Certificate: CD
resource "aws_route53_record" "cd_cert_validation" {
  zone_id = data.aws_route53_zone.nuuday.id
  name    = aws_acm_certificate.cd.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.cd.domain_validation_options.0.resource_record_type
  ttl     = "60"

  records = [aws_acm_certificate.cd.domain_validation_options.0.resource_record_value]
}


resource "aws_acm_certificate" "cd" {
  domain_name       = aws_route53_record.cd.fqdn
  validation_method = "DNS"

  tags = {
    Team = "odin-platform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cd" {
  certificate_arn         = aws_acm_certificate.cd.arn
  validation_record_fqdns = [aws_route53_record.cd_cert_validation.fqdn]
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

module "rds" {
  source = "github.com/terraform-aws-modules/terraform-aws-rds?ref=v2.5.0"

  identifier = "${local.cluster_name}-db"

  engine               = "sqlserver-web"
  engine_version       = "14.00.3192.2.v1"
  major_engine_version = "14.00"
  instance_class       = "db.m5.large"
  allocated_storage    = 20

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  name     = null # see 'identifier'
  username = "demouser"
  password = "YourPwdShouldBeLongAndSecure!"
  port     = "1433"

  multi_az = false

  subnet_ids             = module.vpc.database_subnets
  vpc_security_group_ids = [
    aws_security_group.allow_all_internal.id,
    aws_security_group.db.id,
  ]
  publicly_accessible    = true
  timezone               = "Central Standard Time"
  family                 = "sqlserver-web-14.0"

  tags = {
    Team = "odin-platform"
  }
}

