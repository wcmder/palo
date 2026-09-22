variable "device_groups" {
  description = "Environment device groups, including optional parent and serial assignments."
  type        = any
  default     = {}
}

variable "templates" {
  description = "Stack targets with ordered templates, stack name and serial assignments."
  type        = any
  default     = {}
}
