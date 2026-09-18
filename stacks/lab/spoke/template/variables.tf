variable "items" {
  description = "Template inputs passed through without a duplicated attribute schema. All fields consumed by main.tf must be supplied explicitly."
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
      can(regex("^ethernet[0-9]+/[0-9]+$", item.var.wan_interface)) &&
      can(regex("^ethernet[0-9]+/[0-9]+$", item.var.lan_interface)) &&
      item.var.wan_interface != item.var.lan_interface
    ]), false)
    error_message = "WAN and LAN must be distinct physical Ethernet interface names."
  }

  validation {
    condition = try(alltrue(flatten([for item in values(var.items) : [
      for side in ["wan", "lan"] : try(coalesce(item.var["${side}_ip"], "None"), "None") == "None" ? (
        try(item.var["${side}_prefix_length"], null) == null
        ) : try(
        can(cidrnetmask("${item.var["${side}_ip"]}/32")) &&
        item.var["${side}_prefix_length"] >= 1 && item.var["${side}_prefix_length"] <= 32 &&
        floor(item.var["${side}_prefix_length"]) == item.var["${side}_prefix_length"], false
      )
    ]])), false)
    error_message = "WAN/LAN IP must be None with no prefix, or an IPv4 host address with an integer prefix from 1 to 32."
  }
  validation {
    condition = try(alltrue([for item in values(var.items) :
      try(coalesce(item.var.default_gateway, "None"), "None") == "None" ? true : (
        can(cidrnetmask("${item.var.default_gateway}/32")) &&
        (try(coalesce(item.var.wan_ip, "None"), "None") == "None" ? true : try(
          cidrhost("${item.var.default_gateway}/${item.var.wan_prefix_length}", 0) == cidrhost("${item.var.wan_ip}/${item.var.wan_prefix_length}", 0) && item.var.default_gateway != item.var.wan_ip,
          false
        ))
      )
    ]), false)
    error_message = "Gateway must be None or a valid IPv4 address, different from the assigned WAN IP and in its subnet."
  }
}
