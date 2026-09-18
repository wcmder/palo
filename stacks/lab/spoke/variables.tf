variable "items" {
  description = "Configuration map passed through to policy/template modules without duplicating their resource schemas."
  type        = any
  default     = {}

  validation {
    condition = try(alltrue(flatten([for item in values(var.items) : [
      for serial in try(item.serials, []) : trimspace(serial) != "" && serial == trimspace(serial)
    ]])), false)
    error_message = "Serials must be non-empty strings without surrounding whitespace."
  }
}
