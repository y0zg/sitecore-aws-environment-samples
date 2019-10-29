output "user_data_ecs_windows" {
  value = data.template_file.user_data_windows.rendered
}

output "alb_fqdn" {
  value = aws_lb.lb.dns_name
}
