variable "items" {
  description = "Resources keyed by stable logical keys. Each item supplies its own location."
  type = map(object({
    location = object({
      device_group = optional(object({
        name            = optional(string)
        panorama_device = optional(string)
        rulebase        = optional(string)
      }))
      shared = optional(object({
        rulebase = optional(string)
      }))
      vsys = optional(object({
        name        = optional(string)
        ngfw_device = optional(string)
      }))
    })
    rules = list(object({
      active_active_device_binding = optional(string)
      audit_comment_version        = optional(string)
      audit_comment_wo             = optional(string)
      description                  = optional(string)
      destination_addresses        = optional(list(string))
      destination_translation = optional(object({
        dns_rewrite = optional(object({
          direction = optional(string)
        }))
        translated_address = optional(string)
        translated_port    = optional(number)
      }))
      destination_zone = optional(list(string))
      disabled         = optional(bool)
      dynamic_destination_translation = optional(object({
        distribution       = optional(string)
        translated_address = optional(string)
        translated_port    = optional(number)
      }))
      group_tag        = optional(string)
      name             = string
      nat_type         = optional(string)
      service          = optional(string)
      source_addresses = optional(list(string))
      source_translation = optional(object({
        dynamic_ip = optional(object({
          fallback = optional(object({
            interface_address = optional(object({
              floating_ip = optional(string)
              interface   = optional(string)
              ip          = optional(string)
            }))
            translated_address = optional(list(string))
          }))
          translated_address = optional(list(string))
        }))
        dynamic_ip_and_port = optional(object({
          interface_address = optional(object({
            floating_ip = optional(string)
            interface   = optional(string)
            ip          = optional(string)
          }))
          translated_address = optional(list(string))
        }))
        static_ip = optional(object({
          bi_directional     = optional(string)
          translated_address = optional(string)
        }))
      }))
      source_zones = optional(list(string))
      tag          = optional(list(string))
      target = optional(object({
        devices = optional(list(object({
          name = string
          vsys = optional(list(object({
            name = string
          })))
        })))
        negate = optional(bool)
        tags   = optional(list(string))
      }))
      to_interface = optional(string)
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for item in values(var.items) : length([for scope, value in item.location : scope if value != null]) == 1])
    error_message = "Each item must set exactly one location scope."
  }

  validation {
    condition     = alltrue([for item in values(var.items) : length(distinct([for rule in item.rules : rule.name])) == length(item.rules)])
    error_message = "Rule names must be unique within each policy."
  }
  validation {
    condition     = length(distinct([for item in values(var.items) : jsonencode(item.location)])) == length(var.items)
    error_message = "Each policy item must own a different location."
  }
}
