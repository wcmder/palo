mock_provider "panos" {}

variables {
  templates = {
    spoke = {
      name        = "spoke-network"
      stack       = "spoke-stack"
      description = "Terraform-managed spoke"
      # Shared settings in locals.tf; select the WAN/LAN protection profiles.
      zone_protection_profile_set      = "standard"
      interface_management_profile_set = "ping_only"
      var = {
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
      }
      serials = ["PA_A_SERIAL", "PA_B_SERIAL", "PA_C_SERIAL"]
    }
  }

}

# Exercise the real dev inputs, including both complete protection profiles.
run "dev_zone_protection" {
  command = apply
  assert {
    condition = (
      module.spoke_template.names.interface_management_profiles == {
        wan = "wan-ping", lan = "lan-ping", mgmt = "mgmt-ping"
      } &&
      local.templates.spoke.interface_management_profiles.wan.ping &&
      local.templates.spoke.interface_management_profiles.lan.ping &&
      local.templates.spoke.interface_management_profiles.mgmt.ping
    )
    error_message = "Root inputs must resolve the shared ping-only profile set."
  }
  assert {
    condition     = length(module.spoke_template.name_id.zone_protection_profiles) == 2
    error_message = "The spoke template must create both WAN and LAN protection profiles."
  }
  assert {
    condition     = jsondecode(base64decode(module.spoke_template.name_id.zone_protection_profiles[local.templates.spoke.zone_protection_profiles.wan.name])).location.template.name == var.templates.spoke.name
    error_message = "Zone protection profiles must belong to the spoke Panorama template."
  }
}

run "zone_profile_attachments" {
  command = apply
  module { source = "../../stacks/dev/spoke_template" }
  variables {
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
      var = {
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
      }
      zone_protection_profiles = {
        wan = { name = "test-wan-protection", discard_ip_spoof = false }
        lan = { name = "test-lan-protection", discard_ip_spoof = true }
      }
    }
  }
  assert {
    condition     = module.zones.zone_protection_profiles["wan"] == "test-wan-protection" && module.zones.zone_protection_profiles["lan"] == "test-lan-protection"
    error_message = "WAN and LAN must each reference the correct created profile."
  }
}
