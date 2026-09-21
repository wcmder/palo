mock_provider "panos" {}

run "parent_nat_and_security" {
  command = apply
  module { source = "../../stacks/dev/policies/common" }
  variables {
    item = { device_group = "parent", lan_zone = "inside", wan_zone = "outside", wan_interface = "ethernet1/3", default_security_rules = [{ name = "intrazone-default", action = "deny", log_end = true }] }
  }
  assert {
    condition     = length(output.name_id.nat) == 1 && jsondecode(base64decode(output.name_id.nat.common)).location.device_group.name == "parent" && jsondecode(base64decode(output.name_id.nat.common)).location.device_group.rulebase == "pre-rulebase"
    error_message = "NAT must be installed in the configured parent pre-rulebase."
  }
  assert {
    condition     = jsondecode(base64decode(output.name_id.security.common)).names == ["allow-lan-wan-tcp-22", "allow-lan-wan-icmp", "deny-other-lan-wan"]
    error_message = "TCP/22 and ICMP allows must precede the LAN-to-WAN deny."
  }
  assert {
    condition     = jsondecode(base64decode(output.name_id.services["tcp-22"])).location.device_group.name == "parent"
    error_message = "Each service must be scoped to its own parent group."
  }
}

run "common_policies_without_templates" {
  command = apply
  module { source = "../../stacks/dev/policies/common" }
  variables {
    item = {
      device_group           = "parent"
      lan_zone               = "inside"
      wan_zone               = "outside"
      wan_interface          = "ethernet1/3"
      default_security_rules = [{ name = "intrazone-default", action = "deny", log_end = true }]
    }
  }
  assert {
    condition     = jsondecode(base64decode(output.name_id.nat.common)).location.device_group.name == "parent"
    error_message = "The policy stack must operate independently of any template stack."
  }
}

run "default_security_deny" {
  command = apply
  module { source = "../../stacks/modules/panos/policy/default_security" }
  variables {
    items = {
      parent = {
        location = { device_group = { name = "parent" } }
        rules    = [{ name = "intrazone-default", action = "deny", log_end = true }]
      }
    }
  }
  assert {
    condition     = panos_default_security_policy.this["parent"].rules[0].action == "deny" && panos_default_security_policy.this["parent"].rules[0].log_end
    error_message = "The intrazone fallback must deny and log traffic."
  }
}
