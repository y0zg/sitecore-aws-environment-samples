variable "ec2_instance_type" {
  type    = string
  default = "m4.xlarge"
}

variable "ecs_instance_count" {
  type    = number
  default = 1
}
