variable "items" {
  description = "Template inputs passed through without a duplicated attribute schema. All fields consumed by main.tf must be supplied explicitly."
  type        = any
  default     = {}

  validation {
    condition = try(alltrue([for field in ["name", "stack"] :
      length(distinct([for item in values(var.items) : item[field]])) == length(var.items)
    ]), false)
    error_message = "Each configuration must have a unique template name and stack."
  }

  # WAN and LAN must not create two resources owning the same interface.
  validation {
    condition     = alltrue([for item in values(var.items) : item.var.wan_interface != item.var.lan_interface])
    error_message = "WAN and LAN must reference different interfaces."
  }
}
