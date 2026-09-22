variable "device_groups" {
  description = "Environment device groups, including optional parent and serial assignments."
  type        = any
  default     = {}
}

variable "templates" {
  description = "Stack definitions with name, ordered template names and serials."
  type        = any
  default     = {}
}
