output "lb_external_fqdn" {
  value = aws_lb.lb_external.dns_name
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

output "grafana_access_key_id" {
  value = aws_iam_access_key.grafana.id
  description = "The access key ID Grafana's CloudWatch user"
}

output "grafana_secret_access_key" {
  value = aws_iam_access_key.grafana.secret
  description = "The secret access key for Grafana's CloudWatch user"
}
