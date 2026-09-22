variable "items" {
  description = "Resources keyed by stable logical keys."
  type = map(object({
    copy_tos = optional(bool)
    disabled = optional(bool)
    erspan   = optional(bool)
    keep_alive = optional(object({
      enable     = optional(bool)
      hold_timer = optional(number)
      interval   = optional(number)
      retry      = optional(number)
    }))
    local_address = optional(object({
      floating_ip = optional(string)
      interface   = optional(string)
      ip          = optional(string)
    }))
    location = object({
      ngfw = optional(object({
        ngfw_device = optional(string)
      }))
      template = optional(object({
        name            = optional(string)
        ngfw_device     = optional(string)
        panorama_device = optional(string)
      }))
      template_stack = optional(object({
        name            = optional(string)
        ngfw_device     = optional(string)
        panorama_device = optional(string)
      }))
    })
    name = string
    peer_address = optional(object({
      ip = optional(string)
    }))
    ttl              = optional(number)
    tunnel_interface = optional(string)
  }))
  default = {}
}
