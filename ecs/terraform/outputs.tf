output "lb_external_fqdn" {
  value = aws_lb.lb_external.dns_name
}

output "service_fqdns" {
  value = module.service.*.service_fqdn
}

output "rds_endpoint" {
  value = module.rds.this_db_instance_endpoint
}

