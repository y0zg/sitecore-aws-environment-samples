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
