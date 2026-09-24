variable "items" {
  description = "Loopback interfaces keyed by stable logical keys."
  type = map(object({
    adjust_tcp_mss = optional(object({
      enable              = optional(bool)
      ipv4_mss_adjustment = optional(number)
      ipv6_mss_adjustment = optional(number)
    }))
    comment                      = optional(string)
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
    location = object({
      ngfw = optional(object({
        ngfw_device = optional(string)
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
