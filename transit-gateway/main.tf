terraform {
  required_version = "~> 0.12"
}

provider "aws" {
  region = "eu-central-1"
}

# VPCs

module "vpc_left" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v2.39.0"

  name = "vpc-left-asore"
  cidr = "10.0.0.0/16"

  azs            = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  enable_nat_gateway = false

  tags = {
    team   = "odin-platform"
    author = "asore@nuuday.dk"
  }
}

module "vpc_right" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v2.39.0"

  name = "vpc-right-asore"
  cidr = "10.1.0.0/16"

  azs            = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  public_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]

  enable_nat_gateway = false

  tags = {
    team   = "odin-platform"
    author = "asore@nuuday.dk"
  }
}

# TGW

module "tgw" {
  source = "github.com/terraform-aws-modules/terraform-aws-transit-gateway?ref=v1.1.0"

  name = "asore-tgw"

  vpc_attachments = {
    left = {
      vpc_id      = module.vpc_left.vpc_id
      subnet_ids  = module.vpc_left.public_subnets
      dns_support = true

      tgw_routes = [
        {
          destination_cidr_block = module.vpc_left.vpc_cidr_block
        },
      ]
    }


    right = {
      vpc_id      = module.vpc_right.vpc_id
      subnet_ids  = module.vpc_right.public_subnets
      dns_support = true

      tgw_routes = [
        {
          destination_cidr_block = module.vpc_right.vpc_cidr_block
        },
      ]
    }
  }
}

# Instances

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

module "instance_left" {
  source = "github.com/terraform-aws-modules/terraform-aws-ec2-instance?ref=v2.15.0"

  name           = "left"
  instance_count = 1

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "ASORE"

  subnet_id = module.vpc_left.public_subnets.0
  vpc_security_group_ids = [
    aws_security_group.allow_me_left.id,
    module.vpc_left.default_security_group_id,
  ]
}

module "instance_right" {
  source = "github.com/terraform-aws-modules/terraform-aws-ec2-instance?ref=v2.15.0"

  name           = "right"
  instance_count = 1

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "ASORE"

  subnet_id = module.vpc_right.public_subnets.0
  vpc_security_group_ids = [
    aws_security_group.allow_me_right.id,
    module.vpc_right.default_security_group_id,
  ]
}

resource "aws_security_group" "allow_me_left" {
  name   = "AllowMeLeft"
  vpc_id = module.vpc_left.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "80.62.25.84/32",
      module.vpc_right.vpc_cidr_block,
    ]
  }
}

resource "aws_security_group" "allow_me_right" {
  name   = "AllowMeRight"
  vpc_id = module.vpc_right.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "80.62.25.84/32",
      module.vpc_left.vpc_cidr_block,
    ]
  }
}

