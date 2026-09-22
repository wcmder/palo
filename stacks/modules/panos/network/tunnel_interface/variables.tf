variable "items" {
  description = "Resources keyed by stable logical keys."
  type = map(object({
    bonjour = optional(object({
      enable    = optional(bool)
      group_id  = optional(number)
      ttl_check = optional(bool)
    }))
    comment                      = optional(string)
    df_ignore                    = optional(bool)
    interface_management_profile = optional(string)
    ip = optional(list(object({
      name = string
    })))
    ipv6 = optional(object({
      address = optional(list(object({
        anycast = optional(object({
        }))
        enable_on_interface = optional(bool)
        name                = string
        prefix = optional(object({
        }))
      })))
      enabled      = optional(bool)
      interface_id = optional(string)
    }))
    link_tag = optional(string)
    location = object({
      ngfw = optional(object({
        ngfw_device = optional(string)
      }))
      shared = optional(object({
      }))
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
      }))
    })
    mtu             = optional(number)
    name            = string
    netflow_profile = optional(string)
  }))
  default = {}
}
