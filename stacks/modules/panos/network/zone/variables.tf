variable "items" {
  description = "Resources keyed by stable logical keys. Each item supplies its own location."
  type = map(object({
    device_acl = optional(object({
      exclude_list = optional(list(string))
      include_list = optional(list(string))
    }))
    enable_device_identification = optional(bool)
    enable_user_identification   = optional(bool)
    location = object({
      template = optional(object({
        name            = optional(string)
        ngfw_device     = optional(string)
        panorama_device = optional(string)
        vsys            = optional(string)
      }))
      template_stack = optional(object({
        name            = optional(string)
        ngfw_device     = optional(string)
        panorama_device = optional(string)
        vsys            = optional(string)
      }))
      vsys = optional(object({
        name        = optional(string)
        ngfw_device = optional(string)
      }))
    })
    name = string
    network = optional(object({
      enable_packet_buffer_protection = optional(bool)
      external                        = optional(list(string))
      layer2                          = optional(list(string))
      layer3                          = optional(list(string))
      log_setting                     = optional(string)
      net_inspection                  = optional(bool)
      tap                             = optional(list(string))
      tunnel = optional(object({
      }))
      virtual_wire            = optional(list(string))
      zone_protection_profile = optional(string)
    }))
    user_acl = optional(object({
      exclude_list = optional(list(string))
      include_list = optional(list(string))
    }))
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
