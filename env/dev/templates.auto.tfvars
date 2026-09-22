# Network template/stack settings and firewall assignments.
templates = {
  common = {
    name = "common-network"

    description = "Terraform-managed"

    # Shared settings in locals.tf
    zone_protection_profile_set      = "standard"
    interface_management_profile_set = "ping_only"

    var = {
      data_virtual_router   = "data"
      mgmt_virtual_router   = "mgmt"
      wan_interface         = "ethernet1/1"
      lan_interface         = "ethernet1/2"
      lan_subinterface_tag  = 10
      mgmt_subinterface_tag = 20
      mgmt_zone             = "mgmt"
      wan_zone              = "wan"
      lan_zone              = "lan"
      wan_ip                = "None"
      default_gateway       = "None"
      lan_ip                = "None"
      mgmt_ip               = "None"
    }

  }
}

template_stacks = {
  spoke = {
    name        = "spoke-stack"
    description = "Terraform-managed"
    templates   = ["common"]
    serials     = ["007954000920842"]
  }
}
