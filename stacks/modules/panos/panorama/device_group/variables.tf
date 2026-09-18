variable "items" {
  description = "Resources keyed by stable logical keys. Each item supplies its own location."
  type = map(object({
    authorization_code = optional(string)
    description        = optional(string)
    devices = optional(list(object({
      name = string
      vsys = optional(list(string))
    })))
    location = object({
      panorama = optional(object({
        panorama_device = optional(string)
      }))
    })
    name      = string
    templates = optional(list(string))
  }))
  default = {}

  validation {
    condition     = alltrue([for item in values(var.items) : length([for scope, value in item.location : scope if value != null]) == 1])
    error_message = "Each item must set exactly one location scope."
  }

  validation {
    condition     = length(distinct([for item in values(var.items) : item.name])) == length(var.items)
    error_message = "Names must be unique within a module call so name_id keys are unambiguous; use separate module calls for duplicate names in different scopes."
  }
}
