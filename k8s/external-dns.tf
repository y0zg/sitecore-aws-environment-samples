locals {
  # Latest as of time of writing.
  # Found on: https://github.com/kubernetes-sigs/external-dns
  external_dns_version = "0.7.1"
}

resource "aws_iam_role" "external_dns" {
  name_prefix = "${local.cluster_name}-ext-dns"
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

resource "aws_iam_role_policy" "external_dns" {
  name = "ExternalDns"
  role = aws_iam_role.external_dns.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/${aws_route53_zone.this.zone_id}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

data "helm_repository" "bitnami" {
  name = "bitnami"
  url  = "https://charts.bitnami.com/bitnami"
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  chart      = "external-dns"
  repository = data.helm_repository.bitnami.metadata.0.name
  namespace  = kubernetes_namespace.external_dns.metadata.0.name

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = data.aws_region.current.name
  }

  # Prevents "ALIAS" A records from being created.
  # They're specific to AWS and doesn't comply with the DNS RFC.
  set {
    name  = "aws.preferCNAME"
    value = "true"
  }

  # ExternalDNS creates TXT records with the same name as the CNAME
  # to keep track of which records ExternalDNS "owns".
  # TXT records need to be prefixed with something to avoid colissions.
  # This sets the prefix :-)
  set {
    name  = "txtPrefix"
    value = "foo"
  }

  # By default, both Ingress and Service objects are scanned to find out
  # which hostnames to create DNS records for.
  # This forces ExternalDNS to only scan Ingress objects.
  set {
    name  = "sources.0"
    value = "ingress"
  }

  # Make ExternalDNS's service account assume the given IAM Role.
  # This is achieved through "IAM Roles for Service Accounts" (IRSA).
  set_string {
    name  = "rbac.serviceAccountAnnotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns.arn
  }

  # Ensure ExternalDNS pods only run on Linux nodes,
  # in case we have Windows nodes in our cluster too.
  set_string {
    name  = "nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  depends_on = [
    module.eks,
  ]
}

