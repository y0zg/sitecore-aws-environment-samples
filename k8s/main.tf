provider "aws" {
  region = "eu-central-1"
  profile = "nuuday_digital_dev"
}

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
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
  version                = "1.10"
}

data "aws_availability_zones" "available" {}

data "aws_region" "current" {}

locals {
  cluster_name = "test-eks-${random_string.suffix.result}"

  alb_ingress_service_account_name = "alb-ingress-controller"
  alb_ingress_service_account_namespace = "kube-system"

  tags = {
    team = "odin-platform"
    billing = "odin-platform"
    author = "asore@nuuday.dk"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.6"

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
  source  = "github.com/terraform-aws-modules/terraform-aws-eks?ref=v8.2.0"

  cluster_name = local.cluster_name
  subnets      = module.vpc.private_subnets

  tags = local.tags

  enable_irsa = true

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name = "linux-worker-group"
      instance_type = "t2.medium"
      platform = "linux"
      asg_max_size = var.linux_workers_count
      asg_min_size = var.linux_workers_count
      asg_desired_capacity = var.linux_workers_count
    },

    {
      name = "windows-worker-group"
      instance_type = "m5.large"
      platform = "windows"
      asg_max_size = var.windows_workers_count
      asg_min_size = var.windows_workers_count
      asg_desired_capacity = var.windows_workers_count
    }
  ]

  map_roles    = var.map_roles
  map_users    = var.map_users
  map_accounts = var.map_accounts
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

# Ingress: IAM

data "http" "alb_ingress_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/iam-policy.json"
}

resource "aws_iam_policy" "alb_ingress" {
  name = "ALBIngressControllerIAMPolicy-asore"
  path = "/odin/"

  policy = data.http.alb_ingress_policy.body
}

resource "aws_iam_role" "alb_ingress" {
  name = "eks-alb-ingress-controller"
  path = "/odin/"

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
  role = aws_iam_role.alb_ingress.name
  policy_arn = aws_iam_policy.alb_ingress.arn
}

resource "kubernetes_service_account" "alb_ingress" {
  metadata {
    name = local.alb_ingress_service_account_name
    namespace = local.alb_ingress_service_account_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_ingress.arn
    }
  }
}

# Output 
output "kubeconfig_filename" {
  value = module.eks.kubeconfig_filename
}

output "eks_cluster_name" {
  value = module.eks.cluster_id
}

# DNS

#locals {
#  lb_fqdn = "aadb05ce8525811ea9c390690c91317e-642166da4599e702.elb.eu-central-1.amazonaws.com"
#}
#
#data "aws_route53_zone" "this" {
#  name = "aws.nuuday.nu"
#}
#
#resource "aws_route53_record" "cd" {
#  zone_id = data.aws_route53_zone.this.id
#  name = "asore-cd.aws.nuuday.nu"
#  type = "CNAME"
#  records = [local.lb_fqdn]
#  ttl = 300
#}
#
#resource "aws_route53_record" "cm" {
#  zone_id = data.aws_route53_zone.this.id
#  name = "asore-cm.aws.nuuday.nu"
#  type = "CNAME"
#  records = [local.lb_fqdn]
#  ttl = 300
#}
#
#resource "aws_route53_record" "sis" {
#  zone_id = data.aws_route53_zone.this.id
#  name = "asore-sis.aws.nuuday.nu"
#  type = "CNAME"
#  records = [local.lb_fqdn]
#  ttl = 300
#}
