variable "items" {
  description = "Resources keyed by stable logical keys. Each item supplies its own location."
  type = map(object({
    default_vsys = optional(string)
    description  = optional(string)
    location = object({
      panorama = optional(object({
        panorama_device = optional(string)
      }))
    })
    name = string
  }))
  default = {}

  validation {
    condition     = alltrue([for item in values(var.items) : length([for scope, value in item.location : scope if value != null]) == 1])
    error_message = "Each item must set exactly one location scope."
  }

  validation {
    condition     = length(distinct([for item in values(var.items) : item.name])) == length(var.items)
    error_message = "Names must be unique within a module call to avoid ambiguous resource names; use separate module calls for duplicate names in different scopes."
  }
}
