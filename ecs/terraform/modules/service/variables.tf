variable "ecs_cluster_id" {
  type = string
  description = "ID of the ECS Cluster to deploy the service into."
}

variable "name" {
  type = string
  description = "Name of the ECS Service."
}

variable "docker_image" {
  type = string
  description = "Name of the Docker image to run inside the service."
}

variable "route53_zone_name" {
  type = string
  description = "Name of the Route53 Zone to create the CNAME for ECS Service. E.g.: aws.nuuday.nu. (including the leading '.')"
}

variable "dns_prefix" {
  type = string
  description = "The DNS prefix to create inside the DNS zone specified by route53_zone_id."
}

variable "lb_arn" {
  type = string
  description = "ARN of the ALB in which to create a listener for the ECS service."
}

variable "lb_listener_arn" {
  type = string
  description = "ARN of the LB listener to which the listener rule will be attached."
}

variable "vpc_id" {
  type = string
  description = "ID of the VPC in which the load balancer is deployed."
}
