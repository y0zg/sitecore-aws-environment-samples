output "lb_fqdn" {
  value = aws_lb.external.dns_name
}
