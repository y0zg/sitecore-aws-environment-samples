locals {
  # Latest as of time of writing.
  # Found on: https://cert-manager.io/docs/installation/kubernetes/
  cert_manager_version = "0.14.1"
}

resource "aws_iam_role" "cert_manager" {
  name_prefix = "${local.cluster_name}-cert-manager"
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

  tags = local.tags
}

resource "aws_iam_role_policy" "cert_manager" {
  name = "CertManager"
  role = aws_iam_role.cert_manager.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "route53:GetChange",
            "Resource": "arn:aws:route53:::change/*"
        },
        {
            "Effect": "Allow",
            "Action": [
              "route53:ChangeResourceRecordSets",
              "route53:ListResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/${aws_route53_zone.this.zone_id}"
        },
        {
            "Effect": "Allow",
            "Action": "route53:ListHostedZonesByName",
            "Resource": "*"
        }
    ]
}
EOF
}


resource "null_resource" "cert_manager_crds" {
  provisioner "local-exec" {
    command = join(" ", [
      "kubectl apply",
      "--validate=false",
      "--token='${data.aws_eks_cluster_auth.cluster.token}'",
      "--server=${data.aws_eks_cluster.cluster.endpoint}",
      "-f https://github.com/jetstack/cert-manager/releases/download/v${local.cert_manager_version}/cert-manager.crds.yaml",
    ])
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  chart      = "cert-manager"
  repository = data.helm_repository.jetstack.metadata.0.name
  namespace  = kubernetes_namespace.cert_manager.metadata.0.name

  set {
    name  = "global.rbac.create"
    value = "true"
  }

  set_string {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cert_manager.arn
  }

  set_string {
    name  = "nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
}
