variable "item" {
  description = "Required shared network template configuration."
  type        = any
  nullable    = false

  validation {
    condition     = var.item.var.wan_interface != var.item.var.lan_interface
    error_message = "WAN and LAN must reference different interfaces."
  }
}
