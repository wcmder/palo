variable "items" {
  description = "Resources keyed by stable logical keys, with per-item location."
  type = map(object({
    description = optional(string)
    location = object({
      template = optional(object({
        name            = optional(string)
        panorama_device = optional(string)
      }))
      template_stack = optional(object({
        name            = optional(string)
        panorama_device = optional(string)
      }))
    })
    name = string
    type = object({
      as_number       = optional(string)
      device_id       = optional(string)
      device_priority = optional(string)
      egress_max      = optional(string)
      fqdn            = optional(string)
      group_id        = optional(string)
      interface       = optional(string)
      ip_netmask      = optional(string)
      ip_range        = optional(string)
      link_tag        = optional(string)
      qos_profile     = optional(string)
    })
  }))
  default = {}
  validation {
    condition     = alltrue([for item in values(var.items) : length([for scope, value in item.location : scope if value != null]) == 1])
    error_message = "Set exactly one location scope per item."
  }
  validation {
    condition     = length(distinct([for item in values(var.items) : item.name])) == length(var.items)
    error_message = "Names must be unique per module call; use separate calls for different scopes."
  }
  validation {
    condition     = alltrue([for item in values(var.items) : can(regex("^\\$[A-Za-z0-9_][A-Za-z0-9_.-]*$", item.name))])
    error_message = "Template variable names must start with $ followed by a non-empty identifier."
  }
  validation {
    condition     = alltrue([for item in values(var.items) : length([for kind, value in item.type : kind if value != null]) == 1])
    error_message = "Set exactly one template variable type/value."
  }
}
