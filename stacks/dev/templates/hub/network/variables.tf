variable "item" {
  description = "Role template identity and selected shared profiles."
  type        = any
  nullable    = false
}

variable "network" {
  description = "Complete role network inputs, including routing and tunnels."
  type        = any
  nullable    = false

  validation {
    condition     = var.network.wan_interface != var.network.lan_interface
    error_message = "WAN and LAN must reference different interfaces."
  }
}
