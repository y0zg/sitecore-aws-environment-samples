output "lb_external_fqdn" {
  value = aws_lb.lb_external.dns_name
}

output "service_fqdns" {
  value = module.service.*.service_fqdn
}

output "rds_host" {
  value = module.rds.this_db_instance_address
}

output "rds_password" {
  value = random_string.db_password.result
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the provisioned NAT gateways"
  value       = module.vpc.nat_public_ips
}

output "deployment_access_key_id" {
  value = aws_iam_access_key.deployment.id
}

output "deployment_secret_access_key" {
  value = aws_iam_access_key.deployment.secret
}

