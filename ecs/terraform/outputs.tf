output "user_data_ecs_windows" {
  value = data.template_file.user_data_windows.rendered
}

output "lb_external_fqdn" {
  value = aws_lb.lb_external.dns_name
}

output "cd_fqdn" {
  value = aws_route53_record.cd.fqdn
}

