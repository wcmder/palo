mock_provider "panos" {}

variables {
  templates = {
    spoke = {
      zone_protection_profile_set      = "standard"
      interface_management_profile_set = "ping_only"

      name        = "test-spoke-gre"
      description = "Test spoke"
      var = {
        tunnel_interface      = "tunnel.100"
        wan_interface         = "ethernet1/1"
        lan_interface         = "ethernet1/2"
        lan_subinterface_tag  = 20
        mgmt_subinterface_tag = 10
        mgmt_zone             = "mgmt"
        mgmt_virtual_router   = "mgmt"
        wan_zone              = "wan"
        lan_zone              = "lan"
        wan_ip                = "192.0.2.2/30"
        lan_ip                = "198.51.100.1/24"
        mgmt_ip               = "203.0.113.1/24"
        default_gateway       = "192.0.2.1"
        data_virtual_router   = "spoke-vr"

        hub_wan_ip = "10.0.3.2"
        tunnel_ip  = "172.16.101.2/30"
      }
    }
    hub = {
      zone_protection_profile_set      = "standard"
      interface_management_profile_set = "ping_only"

      name        = "test-hub-gre"
      description = "Test hub"
      var = {
        spoke_a_interface     = "tunnel.101"
        spoke_b_interface     = "tunnel.102"
        wan_interface         = "ethernet1/1"
        lan_interface         = "ethernet1/2"
        lan_subinterface_tag  = 20
        mgmt_subinterface_tag = 10
        mgmt_zone             = "mgmt"
        mgmt_virtual_router   = "mgmt"
        wan_zone              = "wan"
        lan_zone              = "lan"
        wan_ip                = "192.0.2.2/30"
        lan_ip                = "198.51.100.1/24"
        mgmt_ip               = "203.0.113.1/24"
        default_gateway       = "192.0.2.1"
        data_virtual_router   = "spoke-vr"
        spoke_a_wan_ip        = "10.0.1.2"
        spoke_b_wan_ip        = "10.0.2.2"
        spoke_a_tunnel_ip     = "172.16.101.1/30"
        spoke_b_tunnel_ip     = "172.16.102.1/30"
      }
    }

    common = {
      name        = "spoke-network"
      description = "Shared device settings"
    }
  }
  template_stacks = {
    hub = {
      name        = "test-hub-stack"
      description = "Test hub"
      templates   = ["hub", "common"]
      serials     = ["HUB_TEST_SERIAL"]
    }
    spoke = {
      name        = "spoke-stack"
      description = "Test stack"
      templates   = ["spoke", "common"]
      serials     = ["PA_A_SERIAL", "PA_B_SERIAL", "PA_C_SERIAL"]
  } }


}

# Exercise the real dev inputs, including both complete protection profiles.
run "dev_zone_protection" {
  command = apply
  assert {
    condition = (
      module.common_template.names.template == "spoke-network" &&
      module.spoke_stack.templates == tolist([
        module.spoke_template.names.template,
        module.common_template.names.template
      ])
    )
    error_message = "The stack must reference the shared common template."
  }
  assert {
    condition = (
      module.spoke_template.names.interface_management_profiles == {
        wan = "wan-ping", lan = "lan-ping", mgmt = "mgmt-ping"
      } &&
      local.interface_management_profiles[
        var.templates.spoke.interface_management_profile_set
      ].wan.ping &&
      local.interface_management_profiles[
        var.templates.spoke.interface_management_profile_set
      ].lan.ping &&
      local.interface_management_profiles[
        var.templates.spoke.interface_management_profile_set
      ].mgmt.ping
    )
    error_message = "Root inputs must resolve the shared ping-only profile set."
  }
  assert {
    condition     = length(module.spoke_template.zone_protection_locations) == 2
    error_message = "Configured role values and memberships must be preserved."
  }
  assert {
    condition = (
      module.spoke_template.zone_protection_locations.wan.template.name ==
      var.templates.spoke.name
    )
    error_message = "Configured role values and memberships must be preserved."
  }
}

run "zone_profile_attachments" {
  command = apply
  module { source = "../../stacks/dev/templates/spoke/network" }
  variables {
    network = {
      tunnel_interface      = "tunnel.100"
      wan_interface         = "ethernet1/1"
      lan_interface         = "ethernet1/2"
      lan_subinterface_tag  = 20
      mgmt_subinterface_tag = 10
      mgmt_zone             = "mgmt"
      mgmt_virtual_router   = "mgmt"
      wan_zone              = "wan"
      lan_zone              = "lan"
      wan_ip                = "192.0.2.2/30"
      lan_ip                = "198.51.100.1/24"
      mgmt_ip               = "203.0.113.1/24"
      default_gateway       = "192.0.2.1"
      data_virtual_router   = "data"

      hub_wan_ip = "10.0.3.2"
      tunnel_ip  = "None"
    }
    item = {
      name        = "test-network"
      stack       = "test-stack"
      description = "Zone protection attachment test"
      serials     = []
      interface_management_profiles = {
        wan  = { name = "wan-ping", ping = true }
        lan  = { name = "lan-ping", ping = true }
        mgmt = { name = "mgmt-ping", ping = true }
      }
      zone_protection_profiles = {
        wan = { name = "test-wan-protection", discard_ip_spoof = false }
        lan = { name = "test-lan-protection", discard_ip_spoof = true }
      }
    }
  }
  assert {
    condition = (
      module.zones.zone_protection_profiles["wan"] == "test-wan-protection" &&
      module.zones.zone_protection_profiles["lan"] == "test-lan-protection"
    )
    error_message = "Configured role values and memberships must be preserved."
  }
}
