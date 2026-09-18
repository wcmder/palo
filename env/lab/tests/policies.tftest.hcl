mock_provider "panos" {}

run "parent_nat_and_security" {
  command = apply
  module { source = "../../stacks/lab/policies/common" }
  variables {
    items = {
      parent = { device_group = "parent", lan_zone = "inside", wan_zone = "outside", wan_interface = "ethernet1/3" }
      other  = { device_group = "other-parent", lan_zone = "lan", wan_zone = "wan", wan_interface = "ethernet1/1" }
    }
  }
  assert {
    condition     = length(output.name_id.nat) == 2 && jsondecode(base64decode(output.name_id.nat.parent)).location.device_group.name == "parent" && jsondecode(base64decode(output.name_id.nat.parent)).location.device_group.rulebase == "pre-rulebase"
    error_message = "NAT must support multiple parent groups and be installed in each parent's pre-rulebase."
  }
  assert {
    condition     = jsondecode(base64decode(output.name_id.security.parent)).names == ["allow-lan-wan-tcp-22", "allow-lan-wan-icmp", "deny-other-lan-wan"]
    error_message = "TCP/22 and ICMP allows must precede the LAN-to-WAN deny."
  }
  assert {
    condition     = jsondecode(base64decode(output.name_id.services.other["tcp-22"])).location.device_group.name == "other-parent"
    error_message = "Each service must be scoped to its own parent group."
  }
}
