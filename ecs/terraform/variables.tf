variable "ec2_instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "ecs_instance_count" {
  type    = number
  default = 2
}
