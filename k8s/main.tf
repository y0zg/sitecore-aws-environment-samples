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

  alb_ingress_service_account_name      = "alb-ingress-controller"
  alb_ingress_service_account_namespace = "kube-system"

  alb_ingress_controller_version = "v1.1.5"

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

module "eks" {
  source = "github.com/terraform-aws-modules/terraform-aws-eks?ref=v10.0.0"

  cluster_name = local.cluster_name
  subnets      = module.vpc.private_subnets
  enable_irsa  = true
  vpc_id       = module.vpc.vpc_id

  node_groups = [
    {
      name             = "primary"
      instance_type    = "t3.nano"
      max_size         = var.linux_workers_count
      min_size         = var.linux_workers_count
      desired_capacity = var.linux_workers_count
    },
  ]

  worker_groups = [
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

# AWS Application Load Balancer Ingress Controller
# Source: https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html

data "http" "alb_ingress_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/${local.alb_ingress_controller_version}/docs/examples/iam-policy.json"
}

resource "aws_iam_policy" "alb_ingress" {
  name_prefix = "ALBIngressControllerIAMPolicy"
  path        = "/odin/"

  policy = data.http.alb_ingress_policy.body
}

resource "aws_iam_role" "alb_ingress" {
  name_prefix = "alb-ingress-controller"
  path        = "/odin/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${module.eks.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity"
    }
  ]
}
EOF
}
#      "Condition": {
#        "StringEquals": {
#          "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:sub": "system:serviceaccount:${local.alb_ingress_service_account_namespace}:${local.alb_ingress_service_account_name}"
#        }
#      }

resource "aws_iam_role_policy_attachment" "alb_ingress" {
  role       = aws_iam_role.alb_ingress.name
  policy_arn = aws_iam_policy.alb_ingress.arn
}
