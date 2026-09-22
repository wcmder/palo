variable "item" {
  type     = any
  nullable = false
}


variable "stack" {
  description = "Created template-stack name for inherited references."
  type        = string
  nullable    = false
}

variable "network" {
  description = "Common network inputs, including interfaces, routing and tunnels."
  type        = any
  nullable    = false
}

variable "mgmt_interface" {
  description = "Inherited management LAN interface name."
  type        = string
  nullable    = false
}
