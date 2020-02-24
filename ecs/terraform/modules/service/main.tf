data "aws_route53_zone" "this" {
  name         = var.route53_zone_name
  private_zone = false
}

data "aws_lb" "this" {
  arn = var.lb_arn
}

data "aws_lb_listener" "this" {
  arn = var.lb_listener_arn
}

resource "aws_ecs_task_definition" "this" {
  family                = var.name
  container_definitions = var.container_definitions_json
  execution_role_arn    = var.task_execution_role_arn
}

resource "aws_lb_target_group" "this" {
  name_prefix          = "${substr(var.name, 0, 5)}-"
  port                 = 8080
  protocol             = var.target_group_protocol
  vpc_id               = var.vpc_id
  deregistration_delay = 1
  slow_start           = 30

  health_check {
    enabled             = true
    protocol            = var.target_group_protocol
    port                = "traffic-port"
    path                = var.health_check_route
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200-499"
  }

  lifecycle {
    create_before_destroy = true
  }
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
    container_port   = var.container_port
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  desired_count = var.desired_task_count

  depends_on = [data.aws_lb_listener.this]
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.lb_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    field  = "host-header"
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
  listener_arn    = var.lb_listener_arn
  certificate_arn = aws_acm_certificate_validation.this.certificate_arn
}
