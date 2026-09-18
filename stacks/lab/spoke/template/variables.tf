variable "items" {
  description = "Template configurations with optional var/interfaces/zones/routers/routes maps. Resource modules own attribute schemas."
  type        = any
  default     = {}

  validation {
    condition = try(alltrue([for field in ["name", "stack"] :
      length(distinct([for item in values(var.items) : item[field]])) == length(var.items)
    ]), false)
    error_message = "Each configuration must have a unique template name and stack."
  }
  validation {
    condition = try(alltrue([for item in values(var.items) :
      length(distinct([for config in values(try(item.interfaces, {})) : config.name])) == length(try(item.interfaces, {}))
    ]), false)
    error_message = "Interface names must be unique within each template."
  }
  validation {
    condition = try(alltrue(flatten([for item in values(var.items) : [
      for config in values(try(item.var, {})) : try(config.type.ip_netmask, "None") == "None" ? true :
      can(cidrhost(config.type.ip_netmask, 0)) || can(cidrhost("${config.type.ip_netmask}/32", 0))
    ]])), false)
    error_message = "IP Netmask variables must contain None, an IP address, or an address/prefix."
  }
}
