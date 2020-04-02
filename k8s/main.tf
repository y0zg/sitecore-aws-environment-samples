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

data "aws_availability_zones" "available" {}

data "aws_region" "current" {}

locals {
  cluster_name = "test-eks-${random_string.suffix.result}"

  ingress_tags = {
    "kubernetes.io/service-name" = "default/nginx-ingress-controller"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
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
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v2.32.0"

  name                 = "test-vpc"
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

resource "aws_lb" "external" {
  name               = "${local.cluster_name}-ext"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets

  tags = merge(
    local.tags,
    local.ingress_tags,
  )
}

resource "aws_lb_target_group" "http" {
  name_prefix = "http"
  port        = 32080
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.tags,
    local.ingress_tags,
  )
}

resource "aws_lb_target_group" "https" {
  name_prefix = "https"
  port        = 32443
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.tags,
    local.ingress_tags,
  )
}

resource "aws_lb_listener" "external_http" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "external_https" {
  load_balancer_arn = aws_lb.external.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_security_group" "worker_http_ingress" {
  name_prefix = "${local.cluster_name}-ingress-http-"
  description = "Allows HTTP access from anywhere to the ingress NodePorts"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from NLB"
    from_port   = 32080
    to_port     = 32080
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
    description = "HTTP from NLB"
    from_port   = 32443
    to_port     = 32443
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
      instance_type    = "t3.large"
      platform         = "linux"
      asg_max_size         = var.linux_workers_count
      asg_min_size         = var.linux_workers_count
      asg_desired_capacity = var.linux_workers_count
      target_group_arns    = [
        aws_lb_target_group.http.id,
        aws_lb_target_group.https.id,
      ]

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
  depends_on = [
    module.eks,
  ]

  count = var.windows_workers_count > 0 ? 1 : 0

  provisioner "local-exec" {
    command = "sh enable-windows-support.sh -k ${module.eks.kubeconfig_filename}"
  }
}

