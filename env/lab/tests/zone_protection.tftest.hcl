mock_provider "panos" {}

# Exercise the real lab inputs, including both complete protection profiles.
run "lab_zone_protection" {
  command = apply
  assert {
    condition     = length(module.templates.name_id.zone_protection_profiles.spoke) == 2
    error_message = "The spoke template must create both WAN and LAN protection profiles."
  }
  assert {
    condition     = jsondecode(base64decode(module.templates.name_id.zone_protection_profiles.spoke["spoke-wan-protection"])).location.template.name == var.templates.spoke.name
    error_message = "Zone protection profiles must belong to the spoke Panorama template."
  }
}

run "zone_profile_attachments" {
  command = apply
  module { source = "../../stacks/lab/spoke_template" }
  variables {
    items = { example = {
      name        = "test-network"
      stack       = "test-stack"
      description = "Zone protection attachment test"
      serials     = []
      var = {
        wan_interface     = "ethernet1/1"
        lan_interface     = "ethernet1/2"
        wan_zone          = "wan"
        lan_zone          = "lan"
        wan_ip            = "None"
        wan_prefix_length = null
        lan_ip            = "None"
        lan_prefix_length = null
        default_gateway   = "None"
        virtual_router    = "data"
      }
      zone_protection_profiles = {
        wan = { name = "test-wan-protection", discard_ip_spoof = false }
        lan = { name = "test-lan-protection", discard_ip_spoof = true }
      }
    } }
  }
  assert {
    condition     = module.zones["example"].zone_protection_profiles["wan"] == "test-wan-protection" && module.zones["example"].zone_protection_profiles["lan"] == "test-lan-protection"
    error_message = "WAN and LAN must each reference the correct created profile."
  }
}
