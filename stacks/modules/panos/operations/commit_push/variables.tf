variable "device_groups" {
  description = "Environment device groups, including optional parent and serial assignments."
  type        = any
  default     = {}
}

variable "templates" {
  description = "Environment templates with name, stack and serial assignments."
  type        = any
  default     = {}
}
