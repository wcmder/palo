variable "items" {
  description = "Resources keyed by stable logical keys, with per-item location."
  type = map(object({
    admin_dist = optional(number)
    bfd = optional(object({
      profile = optional(string)
    }))
    destination = string
    interface   = optional(string)
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
    metric = optional(number)
    name   = string
    nexthop = optional(object({
      discard = optional(object({
      }))
      fqdn       = optional(string)
      ip_address = optional(string)
      next_vr    = optional(string)
      receive = optional(object({
      }))
    }))
    path_monitor = optional(object({
      enable            = optional(bool)
      failure_condition = optional(string)
      hold_time         = optional(number)
      monitor_destinations = optional(list(object({
        count       = optional(number)
        destination = optional(string)
        enable      = optional(bool)
        interval    = optional(number)
        name        = string
        source      = optional(string)
      })))
    }))
    route_table = optional(object({
      both = optional(object({
      }))
      multicast = optional(object({
      }))
      no_install = optional(object({
      }))
      unicast = optional(object({
      }))
    }))
    virtual_router = string
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
}
