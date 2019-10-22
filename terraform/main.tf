terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = "eu-north-1"
  profile = "nuuday_digital_dev"
}

data "aws_ami" "nomad_consul" {
  most_recent = true

  owners = ["self"]

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "name"
    values = ["nomad-consul-ubuntu18-*"]
  }
}

data "aws_ami" "nomad_consul_windows" {
  most_recent = true

  owners = ["self"]

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "name"
    values = ["nomad-consul-windowsserver2019-*"]
  }
}

locals {
  asore_tsunami_ip = "128.76.39.70/32"
}

# Interpolates the key/value pairs in user-data-server.sh
# This shell script is attached to the EC2 instances as "user data",
# which is AWS-speak for "run this on boot".
data "template_file" "user_data_server" {
  template = file("${path.module}/scripts/user-data-server.sh")

  vars = {
    cluster_tag_key = var.cluster_tag_key
    cluster_tag_value = var.cluster_tag_value
    num_servers = var.num_servers
  }
}

# LOAD BALANCER


# NETWORK

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr_block

  azs            = keys(var.vpc_subnets)
  public_subnets = values(var.vpc_subnets)

  tags = {
    Team = "odin-platform"
  }
}

module "servers" {
  source = "github.com/hashicorp/terraform-aws-consul//modules/consul-cluster?ref=v0.7.0"

  cluster_name = "${var.cluster_name}-server"
  cluster_size = var.num_servers
  instance_type = var.server_instance_type

  # EC2 instances will be tagged with these tags in AWS.
  # They're used by Consul for auto-discovering each other and forming a cluster.
  cluster_tag_key = var.cluster_tag_key
  cluster_tag_value = var.cluster_tag_value

  ami_id = var.ami_id == null ? data.aws_ami.nomad_consul.image_id : var.ami_id
  user_data = data.template_file.user_data_server.rendered

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  allowed_ssh_cidr_blocks = [
    "128.76.39.70/32"
  ]

  allowed_inbound_cidr_blocks = [
    "128.76.39.70/32",
    var.vpc_cidr_block
  ]

  ssh_key_name = var.ssh_key_name

  tags = [
    {
      key = "Team"
      value = "odin-platform"
      propagate_at_launch = true
    }
  ]
}

# Interpolates the key/value pairs in user-data-client.sh
# This shell script is attached to the EC2 instances as "user data",
# which is AWS-speak for "run this on boot".
data "template_file" "user_data_client" {
  template = file("${path.module}/scripts/user-data-client.sh")

  vars = {
    cluster_tag_key = var.cluster_tag_key
    cluster_tag_value = var.cluster_tag_value
  }
}

data "template_file" "user_data_consul_client_win" {
  template = file("${path.module}/scripts/Initialize-NomadConsulUserData.ps1")

  vars = {
    cluster_tag_key = var.cluster_tag_key
    cluster_tag_value = var.cluster_tag_value
  }
}

resource "aws_security_group" "allow_rdp_tsunami" {
  name = "allow_rdp_tsunami"
  description = "Allow RDP from Tsunami network"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 3389
    to_port = 3389
    protocol = "tcp"

    cidr_blocks = [
      "128.76.39.70/32"
    ]
  }
}

resource "aws_security_group" "allow_http_healthchecks" {
  name = "allow_healthchecks_from_nlb"
  description = "Allow HTTP health checks from NLB"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "clients" {
  source = "github.com/hashicorp/terraform-aws-nomad//modules/nomad-cluster?ref=v0.5.0"

  cluster_name = "${var.cluster_name}-client"
  instance_type = var.instance_type

  # EC2 instances will be tagged with these tags in AWS.
  # They're used by Consul for auto-discovering each other and forming a cluster.
  cluster_tag_key = "nomad-clients"
  cluster_tag_value = var.cluster_name

  # Fixed size cluster for now.
  min_size = var.num_clients
  max_size = var.num_clients
  desired_capacity = var.num_clients

  ami_id = var.ami_id == null ? data.aws_ami.nomad_consul_windows.image_id : var.ami_id
  user_data = data.template_file.user_data_consul_client_win.rendered

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  health_check_type = "ELB"

  allowed_ssh_cidr_blocks = [
    "128.76.39.70/32"
  ]

  allowed_inbound_cidr_blocks = [
    "128.76.39.70/32",
    var.vpc_cidr_block
  ]

  ssh_key_name = var.ssh_key_name

  security_groups = [
    "${aws_security_group.allow_http_healthchecks.id}",
    "${aws_security_group.allow_rdp_tsunami.id}"
  ]

  tags = [
    {
      key = "Team"
      value = "odin-platform"
      propagate_at_launch = true
    }
  ]
}

resource "aws_lb_target_group" "nomad_clients" {
  name     = "nomad-client-tg"
  port     = 80
  target_type = "instance"
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  stickiness {
    type = "lb_cookie"
    enabled = false
  }

  tags = {
    Team = "odin-platform"
  }
}

data "aws_autoscaling_group" "clients" {
  name = module.clients.asg_name
}

resource "aws_lb" "ingress" {
  name = "nomad-clients-ingress"
  internal = false
  load_balancer_type = "network"
  subnets = module.vpc.public_subnets

  tags = {
    Team = "odin-platform"
  }
}

# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = module.clients.asg_name
  alb_target_group_arn   = "${aws_lb_target_group.nomad_clients.arn}"
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "${aws_lb.ingress.arn}"
  port = "80"
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = "${aws_lb_target_group.nomad_clients.arn}"
  }
}

module "security_group_rules_servers" {
  source = "github.com/hashicorp/terraform-aws-nomad.git//modules/nomad-security-group-rules?ref=v0.5.0"

  security_group_id = "${module.servers.security_group_id}"

  allowed_inbound_cidr_blocks = [
    var.vpc_cidr_block,
    local.asore_tsunami_ip
  ]
}

module "security_group_rules_clients" {
  source = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-security-group-rules?ref=v0.7.0"

  security_group_id = "${module.clients.security_group_id}"

  allowed_inbound_cidr_blocks = [var.vpc_cidr_block]
}

module "consul_iam_policies_clients" {
  source = "github.com/hashicorp/terraform-aws-consul//modules/consul-iam-policies?ref=v0.7.0"

  iam_role_id = module.clients.iam_role_id
}

module "consul_iam_policies_servers" {
  source = "github.com/hashicorp/terraform-aws-consul//modules/consul-iam-policies?ref=v0.7.0"

  iam_role_id = module.servers.iam_role_id
}
