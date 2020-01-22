# Ephemeral Dev Environments

locals {
  zone = "aws.nuuday.nu."
  domain_name = "scdemo.aws.nuuday.nu"
}

data "aws_route53_zone" "this" {
  name = local.zone
}

resource "aws_route53_record" "dev" {
  name = "*.${local.domain_name}"
  type = "CNAME"
  ttl  = "300"

  zone_id = data.aws_route53_zone.this.id

  records = [aws_lb.lb_external.dns_name]
}

module "dev_certificate" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> v2.0"

  domain_name  = "*.${local.domain_name}"
  zone_id      = data.aws_route53_zone.this.id

  subject_alternative_names = [ 
    "*.${local.domain_name}",
  ]

  tags = local.common_tags
}

resource "aws_lb_listener_certificate" "dev_wildcard_certificate" {
  listener_arn    = aws_lb_listener.frontend.arn
  certificate_arn = module.dev_certificate.this_acm_certificate_arn
}

