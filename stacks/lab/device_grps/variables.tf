variable "items" {
  description = "Configuration entries with device-group names and firewall serials."
  type        = any
  default     = {}

  validation {
    condition = alltrue([for item in values(var.items) :
      try(trimspace(item.device_group) != "" && item.device_group == trimspace(item.device_group), false)
    ])
    error_message = "Device-group names must be non-empty and have no surrounding whitespace."
  }
  validation {
    condition = alltrue(flatten([for item in values(var.items) : [
      for serial in try(item.serials, []) : try(trimspace(serial) != "" && serial == trimspace(serial), false)
    ]]))
    error_message = "Serials must be non-empty and have no surrounding whitespace."
  }
  validation {
    condition     = length(distinct(flatten([for item in values(var.items) : try(item.serials, [])]))) == length(flatten([for item in values(var.items) : try(item.serials, [])]))
    error_message = "A serial may only be assigned to one item."
  }
}
