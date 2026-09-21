# Network template/stack settings and firewall assignments.
templates = {
  spoke = {
    name        = "spoke-network"
    stack       = "spoke-stack"
    description = "Terraform-managed spoke"
    # Shared settings in locals.tf; omit this field for no zone protection.
    zone_protection_profile_set = "standard"
    var = {
      wan_interface         = "ethernet1/1"
      lan_interface         = "ethernet1/2"
      lan_subinterface_tag  = 20
      mgmt_subinterface_tag = 10
      mgmt_zone             = "mgmt"
      mgmt_virtual_router   = "mgmt"
      wan_zone              = "wan"
      lan_zone              = "lan"
      wan_ip                = "None"
      wan_prefix_length     = null
      lan_ip                = "None"
      lan_prefix_length     = null
      mgmt_ip               = "None"
      mgmt_prefix_length    = null
      default_gateway       = "None"
      data_virtual_router   = "data"
    }
    serials = ["007954000920842"]
  }
}
