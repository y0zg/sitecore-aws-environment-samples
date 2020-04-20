variable "samples_use_production_lets_encrypt" {
  type    = bool
  default = false
}

variable "linux_workers_count" {
  type    = number
  default = 2
}

variable "windows_workers_count" {
  type    = number
  default = 0
}
