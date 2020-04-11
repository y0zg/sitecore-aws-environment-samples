terraform {
  backend "s3" {
    bucket = "odin-infra-dev"
    key    = "infrastructure/asore/reference-eks.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region  = "eu-north-1"
  profile = "nuuday_digital_dev"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~>1.11"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
    load_config_file       = false
  }
}

data "aws_availability_zones" "available" {}

data "aws_region" "current" {}

locals {
  cluster_name = "test-eks-${lower(random_string.suffix.result)}"
  oidc_issuer  = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")

  parent_dns_zone = "aws.nuuday.nu"
  dns_subdomain   = local.cluster_name

  # nginx servers will listen on these ports on the worker nodes
  ingress_controller_node_ports = {
    http  = 32080
    https = 32443
  }

  tags = {
    team       = "odin-platform"
    billing    = "odin-platform"
    author     = "asore@nuuday.dk"
    repository = "https://gitlab.yousee.dk/odin/infrastructure/sitecore-aws-infrastructure/-/tree/master/k8s"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v2.33.0"

  name                 = local.cluster_name
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    }
  )

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "lb" {
  source = "github.com/terraform-aws-modules/terraform-aws-alb?ref=v5.2.0"

  name               = "${local.cluster_name}-ext"
  load_balancer_type = "network"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    },
    {
      port               = 443
      protocol           = "TCP"
      target_group_index = 1
    },
  ]

  target_groups = [
    {
      name_prefix      = "http"
      backend_protocol = "TCP"
      backend_port     = local.ingress_controller_node_ports.http
      target_type      = "instance"
    },
    {
      name_prefix      = "https"
      backend_protocol = "TCP"
      backend_port     = local.ingress_controller_node_ports.https
      target_type      = "instance"
    },
  ]

  tags = local.tags
}

resource "aws_security_group" "worker_http_ingress" {
  name_prefix = "${local.cluster_name}-ingress-http-"
  description = "Allows HTTP access from anywhere to the ingress NodePorts"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from NLB"
    from_port   = local.ingress_controller_node_ports.http
    to_port     = local.ingress_controller_node_ports.http
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_security_group" "worker_https_ingress" {
  name_prefix = "${local.cluster_name}-ingress-https-"
  description = "Allows HTTPS access from anywhere to the ingress NodePorts"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from NLB"
    from_port   = local.ingress_controller_node_ports.https
    to_port     = local.ingress_controller_node_ports.https
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

module "eks" {
  source = "github.com/terraform-aws-modules/terraform-aws-eks?ref=v10.0.0"

  cluster_name = local.cluster_name
  subnets      = module.vpc.private_subnets
  enable_irsa  = true
  vpc_id       = module.vpc.vpc_id

  worker_groups = [
    {
      instance_type        = "t3.large"
      platform             = "linux"
      asg_max_size         = var.linux_workers_count
      asg_min_size         = var.linux_workers_count
      asg_desired_capacity = var.linux_workers_count
      target_group_arns    = module.lb.target_group_arns

      additional_security_group_ids = [
        aws_security_group.worker_http_ingress.id,
        aws_security_group.worker_https_ingress.id,
      ]
    },

    {
      name                 = "windows-worker-group"
      instance_type        = "m5.large"
      platform             = "windows"
      asg_max_size         = var.windows_workers_count
      asg_min_size         = var.windows_workers_count
      asg_desired_capacity = var.windows_workers_count
    }
  ]

  map_roles    = var.map_roles
  map_users    = var.map_users
  map_accounts = var.map_accounts

  tags = local.tags
}

resource "null_resource" "windows_support" {
  count = var.windows_workers_count > 0 ? 1 : 0

  depends_on = [
    module.eks,
  ]

  provisioner "local-exec" {
    command = "sh enable-windows-support.sh"
    environment = {
      KUBECONFIG         = "${path.module}/${module.eks.kubeconfig_filename}"
      AWS_DEFAULT_REGION = data.aws_region.current.name
    }
  }
}

data "aws_route53_zone" "aws_nuuday" {
  name = local.parent_dns_zone
}

resource "aws_route53_zone" "this" {
  name          = "${local.dns_subdomain}.${local.parent_dns_zone}"
  force_destroy = true

  tags = local.tags
}

resource "aws_route53_record" "ns" {
  zone_id = data.aws_route53_zone.aws_nuuday.zone_id
  name    = "${local.dns_subdomain}.${local.parent_dns_zone}"
  type    = "NS"
  ttl     = "30"

  records = aws_route53_zone.this.name_servers
}
