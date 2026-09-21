variable "items" {
  description = "Interface management profiles keyed by logical role."
  type = map(object({
    name = string
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
    permitted_ips              = optional(list(object({ name = string })), [])
    http                       = optional(bool, false)
    http_ocsp                  = optional(bool, false)
    https                      = optional(bool, false)
    ping                       = optional(bool, false)
    response_pages             = optional(bool, false)
    snmp                       = optional(bool, false)
    ssh                        = optional(bool, false)
    telnet                     = optional(bool, false)
    userid_service             = optional(bool, false)
    userid_syslog_listener_ssl = optional(bool, false)
    userid_syslog_listener_udp = optional(bool, false)
  }))
  default = {}

  validation {
    condition = length(distinct([
      for item in values(var.items) : item.name
    ])) == length(var.items)
    error_message = "Profile names must be unique within a module call."
  }
}
