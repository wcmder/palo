variable "items" {
  description = "Deployment targets keyed by stable names. Each target commits its containers and optionally pushes to explicit firewall serials."
  type = map(object({
    device_group   = string
    template       = string
    template_stack = string
    serials        = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([for item in values(var.items) : alltrue([
      for name in [item.device_group, item.template, item.template_stack] : try(trimspace(name) != "", false)
    ])])
    error_message = "Each target requires non-empty device group, template and template stack names."
  }
  validation {
    condition = alltrue(flatten([for item in values(var.items) : [
      for serial in item.serials : try(trimspace(serial) != "" && serial == trimspace(serial), false)
    ]]))
    error_message = "Serials must be non-empty strings with no surrounding whitespace."
  }
}
