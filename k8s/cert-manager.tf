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
      "--kubeconfig=${module.eks.kubeconfig_filename}",
      "-f https://github.com/jetstack/cert-manager/releases/download/v${local.cert_manager_version}/cert-manager.crds.yaml",
    ])
  }

  depends_on = [
    module.eks,
  ]
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

  depends_on = [
    null_resource.cert_manager_crds,
  ]
}

resource "local_file" "cert_manager_issuers" {
  filename        = "${path.module}/.generated_manifests/issuers.yaml"
  file_permission = "0655"

  content = templatefile("${path.module}/manifests/cert-manager-issuers.yaml.tmpl", {
    author_email = local.tags.author
    dns_zone     = "${local.dns_subdomain}.${local.parent_dns_zone}"
    dns_zone_id  = aws_route53_zone.this.zone_id
    region       = data.aws_region.current.name
  })
}

resource "null_resource" "cert_manager_issuers" {
  depends_on = [
    null_resource.cert_manager_crds,
  ]

  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.cert_manager_issuers.filename}"

    environment = {
      KUBECONFIG = "${path.module}/${module.eks.kubeconfig_filename}"
    }
  }
}
