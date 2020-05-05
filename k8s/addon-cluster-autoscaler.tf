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

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid = "Read"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
    ]

    resources = ["*"]
  }

  statement {
    sid = "Write"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    dynamic "condition" {
      for_each = local.cluster_autoscaler.asg_tags

      content {
        test     = "StringEqualsIgnoreCase"
        variable = "autoscaling:ResourceTag/${condition.key}"
        values   = [condition.value]
      }
    }
  }
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "ClusterAutoscaler"
  role = aws_iam_role.cluster_autoscaler.id

  policy = data.aws_iam_policy_document.cluster_autoscaler.json
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
