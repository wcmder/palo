variable "sites" {
  description = "Sites keyed by stable site identifiers. Empty by default."
  type = map(object({
    device_group   = string
    template       = string
    template_stack = string
    description    = optional(string)
    serials        = optional(list(string), [])
    addresses      = optional(map(string), {})
  }))
  default = {}
}

variable "spokes" {
  description = "Configuration map passed through to policy/template modules without duplicating their resource schemas."
  type        = any
  default     = {}

  validation {
    condition = try(alltrue(flatten([for item in values(var.spokes) : [
      for serial in try(item.serials, []) : trimspace(serial) != "" && serial == trimspace(serial)
    ]])), false)
    error_message = "Serials must be non-empty strings without surrounding whitespace."
  }
}
