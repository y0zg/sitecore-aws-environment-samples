# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# AWS_DEFAULT_REGION

variable "ami_id" {
  description = "The ID of the AMI to run in the cluster. This should be an AMI built from the Packer template under examples/nomad-consul-ami/nomad-consul.json. If no AMI is specified, the template will 'just work' by using the example public AMIs. WARNING! Do not use the example AMIs in a production setting!"
  type        = string
  default     = null
}

variable "provision_load_balancer" {
  description = "Whether to deploy an Amazon Load Balancer which will be attached to the client Auto Scaling Group"
  type = bool
  default = true
}

variable "cluster_name" {
  description = "What to name the cluster and all of its associated resources"
  type        = string
  default     = "nomad-example"
}

variable "instance_type" {
  description = "What kind of instance type to use for the nomad clients"
  type        = string
  default     = "t3.medium"
}

variable "server_instance_type" {
  description = "What kind of instance type to use for the nomad servers"
  type        = string
  default     = "t3.medium"
}

variable "num_servers" {
  description = "The number of server nodes to deploy. We strongly recommend using 3 or 5."
  type        = number
  default     = 3
}

variable "num_clients" {
  description = "The number of client nodes to deploy. You can deploy as many as you need to run your jobs."
  type        = number
  default     = 5
}

variable "cluster_tag_key" {
  description = "The tag the EC2 Instances will look for to automatically discover each other and form a cluster."
  type        = string
  default     = "nomad-servers"
}

variable "cluster_tag_value" {
  description = "Add a tag with key var.cluster_tag_key and this value to each Instance in the ASG. This can be used to automatically find other Consul nodes and form a cluster."
  type        = string
  default     = "auto-join"
}

variable "ssh_key_name" {
  description = "The name of an EC2 Key Pair that can be used to SSH to the EC2 Instances in this cluster. Set to an empty string to not associate a Key Pair."
  type        = string
  default     = "ASORE"
}

variable "vpc_cidr_block" {
  description = "The IP range in CIDR notation which will constitute the VPC in which Nomad/Consul VMs will be deployed."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_subnets" {
  type = map
  default = {
    "eu-north-1a" = "10.0.0.0/23"
    "eu-north-1b" = "10.0.2.0/23"
    "eu-north-1c" = "10.0.4.0/23"
  }
}

