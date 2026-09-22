variable "items" {
  description = "Resources keyed by stable logical keys. Each item supplies its own location."
  type = map(object({
    description      = optional(string)
    disable_override = optional(string)
    location = object({
      device_group = optional(object({
        name            = optional(string)
        panorama_device = optional(string)
      }))
      shared = optional(object({
      }))
      vsys = optional(object({
        name        = optional(string)
        ngfw_device = optional(string)
      }))
    })
    name = string
    protocol = optional(object({
      tcp = optional(object({
        destination_port = optional(string)
        override = optional(object({
          halfclose_timeout = optional(number)
          timeout           = optional(number)
          timewait_timeout  = optional(number)
        }))
        source_port = optional(string)
      }))
      udp = optional(object({
        destination_port = optional(string)
        override = optional(object({
          timeout = optional(number)
        }))
        source_port = optional(string)
      }))
    }))
    tags = optional(list(string))
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
