mock_provider "panos" {}

run "parent_nat_and_security" {
  command = apply
  module { source = "../../stacks/dev/policies/common" }
  variables {
    item = { mgmt_zone = "management", gre_endpoints = ["192.0.2.2", "198.51.100.2"], device_group = "parent", lan_zone = "inside", wan_zone = "outside", wan_interface = "ethernet1/3", default_security_rules = [{ name = "intrazone-default", action = "deny", log_end = true }] }
  }
  assert {
    condition     = length(module.nat.names) == 1 && module.nat.locations.common.device_group.name == "parent" && module.nat.locations.common.device_group.rulebase == "pre-rulebase"
    error_message = "NAT must be installed in the configured parent pre-rulebase."
  }
  assert {
    condition     = module.security-pre.names.common == ["allow-gre-management", "allow-tcp-22", "allow-icmp"] && module.security-post.names.common == ["default-deny"]
    error_message = "TCP/22 and ICMP allows must precede the LAN-to-WAN deny."
  }
  assert {
    condition     = module.services.locations.tcp_22.device_group.name == "parent"
    error_message = "Each service must be scoped to its own parent group."
  }
}

run "common_policies_without_templates" {
  command = apply
  module { source = "../../stacks/dev/policies/common" }
  variables {
    item = {
      mgmt_zone              = "management"
      gre_endpoints          = ["192.0.2.2", "198.51.100.2"]
      device_group           = "parent"
      lan_zone               = "inside"
      wan_zone               = "outside"
      wan_interface          = "ethernet1/3"
      default_security_rules = [{ name = "intrazone-default", action = "deny", log_end = true }]
    }
  }
  assert {
    condition     = module.nat.locations.common.device_group.name == "parent"
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
