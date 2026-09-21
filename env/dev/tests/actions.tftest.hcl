mock_provider "panos" {}

variables {
  templates = {
    spoke = {
      name        = "spoke-network"
      stack       = "spoke-stack"
      description = "Terraform-managed spoke"
      # Shared settings in locals.tf; select the WAN/LAN protection profiles.
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
        wan_ip                = "192.0.2.2/30"
        lan_ip                = "198.51.100.1/24"
        mgmt_ip               = "203.0.113.1/24"
        default_gateway       = "192.0.2.1"
        data_virtual_router   = "spoke-vr"
      }
      serials = ["PA_A_SERIAL", "PA_B_SERIAL", "PA_C_SERIAL"]
    }
  }

  policies = { common = {
    device_group           = "parent"
    lan_zone               = "lan"
    wan_zone               = "wan"
    wan_interface          = "ethernet1/1"
    default_security_rules = [{ name = "intrazone-default", action = "deny", log_end = true }]
  } }
}

run "independent_policy_and_template_membership" {
  command = apply
  module { source = "../../stacks/modules/panos/operations/commit_push" }
  variables {
    device_groups = {
      parent_a   = { serials = [] }
      parent_b   = { parent = null, serials = [] }
      branches_a = { parent = "parent_a", serials = ["A", "H"] }
      branches_b = { parent = "parent_b", serials = ["B"] }
    }
    templates = { spoke = {
      name        = "test-network"
      stack       = "test-stack"
      description = "Test network"
      serials     = ["A", "B"]
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
        data_virtual_router   = "test-vr"
      }
      }, hub = {
      name        = "hub-network"
      stack       = "hub-stack"
      description = "Test network"
      serials     = ["H"]
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
        data_virtual_router   = "test-vr"
      }
    } }
  }


  assert {
    condition     = keys(output.name_id.push) == ["branches_a/hub", "branches_a/spoke", "branches_b/spoke"]
    error_message = "Push targets must be policy/template intersections, excluding empty parents."
  }
  assert {
    condition     = keys(output.policy_push_items) == ["branches_a", "branches_b"] && output.policy_push_items.branches_a.serials == ["A", "H"]
    error_message = "Policy-only pushes must retain full group membership and exclude unassigned parents."
  }
  assert {
    condition     = keys(output.template_push_items) == ["hub", "spoke"] && output.template_push_items.spoke.serials == ["A", "B"]
    error_message = "Template-only pushes must span the stack's assigned devices across policy groups."
  }
  assert {
    condition     = output.push_targets["branches_a/spoke"].serials == tolist(["A"]) && output.push_targets["branches_b/spoke"].serials == tolist(["B"])
    error_message = "Sharing a template must not push devices in a different policy group."
  }
  assert {
    condition     = output.push_targets["branches_a/hub"].serials == tolist(["H"])
    error_message = "One policy group must support separate hub and spoke stacks."
  }


  assert {
    condition     = output.deployment_items["branches_a/spoke"].device_groups == tolist(["parent_a", "branches_a"])
    error_message = "Scoped commits must include the inherited parent policy."
  }
}

run "policy_push_without_templates" {
  command = plan
  module { source = "../../stacks/modules/panos/operations/commit_push" }
  variables {
    device_groups = { branch = { serials = ["A"] }, unused = { serials = [] } }
    templates     = {}
  }
  assert {
    condition     = keys(output.policy_push_items) == ["branch"] && length(output.template_push_items) == 0 && length(output.deployment_items) == 0
    error_message = "Policy-only pushes must exist without any template or combined deployment target."
  }
}

run "reject_missing_parent" {
  command = plan
  variables {
    device_groups = { parent = { serials = [] }, bad = { parent = "missing", serials = [] } }

  }
  expect_failures = [var.device_groups]
}

run "reject_hierarchy_cycle" {
  command = plan
  variables {
    device_groups = {
      parent = { serials = [] }
      a      = { parent = "b", serials = [] }
      b      = { parent = "a", serials = [] }
    }

  }
  expect_failures = [var.device_groups]
}

run "reject_blank_serial" {
  command = plan
  variables {
    device_groups = { parent = { serials = [] } }
    templates = { spoke = {
      zone_protection_profile_set = "standard"
      name                        = "test-network"
      stack                       = "test-stack"
      description                 = "Test network"
      serials                     = [""]
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
        data_virtual_router   = "test-vr"
      }
    } }
  }
  expect_failures = [var.templates]
}

run "shared_actions_template_only" {
  command = plan
  module { source = "../../stacks/modules/panos/operations/commit_push" }
  variables {
    device_groups = {}
    templates = {
      network = { name = "network", stack = "network-stack", serials = ["A"] }
      unused  = { name = "unused", stack = "unused-stack", serials = [] }
    }
  }
  assert {
    condition     = keys(output.name_id.templates) == ["network"] && length(output.name_id.policies) == 0 && length(output.deployment_items) == 0
    error_message = "Template-only actions must exist without device groups and exclude empty assignments."
  }
}
