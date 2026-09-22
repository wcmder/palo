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

  spoke = {
    name             = "spoke-network"
    description      = "Spoke GRE tunnel to hub"
    tunnel_interface = "tunnel.100"
    var = {
      hub_wan_ip   = "10.0.3.2"
      tunnel_ip    = "None"
      gre_local_ip = "None"
    }
  }

  hub = {
    name              = "hub-network"
    description       = "Hub GRE tunnels to spoke"
    spoke_a_interface = "tunnel.101"
    spoke_b_interface = "tunnel.102"
    var = {
      hub_wan_ip        = "10.0.3.2"
      spoke_a_wan_ip    = "10.0.1.2"
      spoke_b_wan_ip    = "10.0.2.2"
      spoke_a_tunnel_ip = "None"
      spoke_b_tunnel_ip = "None"
    }
  }

}

template_stacks = {
  spoke = {
    name        = "spoke-stack"
    description = "Terraform-managed"
    templates   = ["spoke", "common"]
    serials     = ["007954000920842", "007954000920860"]
  }
  hub = {
    name        = "hub-stack"
    description = "Terraform-managed"
    templates   = ["hub", "common"]
    serials     = ["007954000920861"]
  }
}
