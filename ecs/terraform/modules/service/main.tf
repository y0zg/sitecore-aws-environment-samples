data "aws_route53_zone" "this" {
  name = var.route53_zone_name
  private_zone = false
}

data "aws_lb" "this" {
  arn = var.lb_arn
}

resource "aws_ecs_task_definition" "this" {
  family = var.name

  container_definitions = <<EOF
[
	{
		"name": "${var.name}",
    "image": "${var.docker_image}",
    "cpu": 512,
    "memory": 2048,
		"portMappings": [
			{
				"containerPort": 80
			}
		]
	}
]
EOF
}

resource "aws_lb_target_group" "this" {
  name     = "${var.name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_ecs_service" "this" {
  name                               = var.name
  cluster                            = var.ecs_cluster_id
  launch_type                        = "EC2"
  task_definition                    = aws_ecs_task_definition.this.arn
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 120

  load_balancer {
    target_group_arn = aws_lb_target_group.this.id
    container_name   = var.name
    container_port   = 80
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  desired_count = 1
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.lb_listener_arn

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    field = "host-header"
    values = [aws_route53_record.this.fqdn]
  }
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.id
  name    = "${var.dns_prefix}.${data.aws_route53_zone.this.name}"
  type    = "CNAME"
  ttl     = "300"

  records = [data.aws_lb.this.dns_name]
}

# Certificate

resource "aws_acm_certificate" "this" {
  domain_name       = aws_route53_record.this.fqdn
  validation_method = "DNS"

  tags = {
    Team = "odin-platform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "this_cert_validation" {
  zone_id = data.aws_route53_zone.this.id
  name    = aws_acm_certificate.this.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.this.domain_validation_options.0.resource_record_type
  ttl     = "60"

  records = [aws_acm_certificate.this.domain_validation_options.0.resource_record_value]
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [aws_route53_record.this_cert_validation.fqdn]
}

resource "aws_lb_listener_certificate" "this" {
  listener_arn = var.lb_listener_arn
  certificate_arn = aws_acm_certificate_validation.this.certificate_arn
}
