locals {
  cluster_autoscaler = {
    asg_tags = {
      "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"               = "true"
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name_prefix = "${local.cluster_name}-autoscaler"
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
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_issuer}:sub": "system:serviceaccount:${kubernetes_namespace.cluster_autoscaler.metadata.0.name}:cluster-autoscaler-aws-cluster-autoscaler"
        }
      }
    }
  ]
}
EOF

  tags = local.tags
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "ClusterAutoscaler"
  role = aws_iam_role.cluster_autoscaler.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "autoscaling:UpdateAutoScalingGroup"
      ],
      "Resource": ["*"],
      "Condition": {
        "StringEqualsIgnoreCase": {
          "autoscaling:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_id}": "owned",
          "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled": "true"
        }
      }
    }
  ]
}
EOF
}

resource "kubernetes_namespace" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler"
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  chart      = "cluster-autoscaler"
  version    = "7.0.0"
  repository = data.helm_repository.stable.metadata.0.name
  namespace  = kubernetes_namespace.cluster_autoscaler.metadata.0.name

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }

  set {
    name  = "rbac.create"
    value = true
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = true
  }

  set_string {
    name  = "rbac.serviceAccountAnnotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler.arn
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_id
  }

  set {
    name  = "autoDiscovery.enabled"
    value = true
  }

  set_string {
    name  = "nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
}
