mock_provider "panos" {}

variables { policies = {} }

run "independent_policy_and_template_membership" {
  command = apply
  variables {
    device_groups = {
      parent_a   = { serials = [] }
      parent_b   = { parent = null, serials = [] }
      branches_a = { parent = "parent_a", serials = ["A", "H"] }
      branches_b = { parent = "parent_b", serials = ["B"] }
    }
    templates = { shared = {
      name        = "test-network"
      stack       = "test-stack"
      description = "Test network"
      serials     = ["A", "B"]
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
        virtual_router    = "test-vr"
      }
      }, hub = {
      name        = "hub-network"
      stack       = "hub-stack"
      description = "Test network"
      serials     = ["H"]
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
        virtual_router    = "test-vr"
      }
    } }
  }
  assert {
    condition     = keys(module.deployment.name_id.push) == ["branches_a/hub", "branches_a/shared", "branches_b/shared"]
    error_message = "Push targets must be policy/template intersections, excluding empty parents."
  }
  assert {
    condition     = keys(module.deployment.policy_push_items) == ["branches_a", "branches_b"] && module.deployment.policy_push_items.branches_a.serials == ["A", "H"]
    error_message = "Policy-only pushes must retain full group membership and exclude unassigned parents."
  }
  assert {
    condition     = keys(module.deployment.template_push_items) == ["hub", "shared"] && module.deployment.template_push_items.shared.serials == ["A", "B"]
    error_message = "Template-only pushes must span the stack's assigned devices across policy groups."
  }
  assert {
    condition     = module.deployment.push_targets["branches_a/shared"].serials == tolist(["A"]) && module.deployment.push_targets["branches_b/shared"].serials == tolist(["B"])
    error_message = "Sharing a template must not push devices in a different policy group."
  }
  assert {
    condition     = module.deployment.push_targets["branches_a/hub"].serials == tolist(["H"])
    error_message = "One policy group must support separate hub and spoke stacks."
  }
  assert {
    condition     = module.device_groups.parents.branches_a == "parent_a" && module.device_groups.parents.branches_b == "parent_b"
    error_message = "Each child must reference its own parent."
  }
  assert {
    condition     = jsondecode(base64decode(module.device_groups.parent_name_id.branches_a)).device_group == "branches_a"
    error_message = "Hierarchy identity must use the provider's device_group import field."
  }
  assert {
    condition     = module.deployment.deployment_items["branches_a/shared"].device_groups == tolist(["parent_a", "branches_a"])
    error_message = "Scoped commits must include the inherited parent policy."
  }
}

run "policy_push_without_templates" {
  command = plan
  variables {
    device_groups = { branch = { serials = ["A"] }, unused = { serials = [] } }
    templates     = {}
  }
  assert {
    condition     = keys(module.deployment.policy_push_items) == ["branch"] && length(module.deployment.template_push_items) == 0 && length(module.deployment.deployment_items) == 0
    error_message = "Policy-only pushes must exist without any template or combined deployment target."
  }
}

run "reject_missing_parent" {
  command = plan
  variables {
    device_groups = { bad = { parent = "missing", serials = [] } }
    templates     = {}
  }
  expect_failures = [var.device_groups]
}

run "reject_hierarchy_cycle" {
  command = plan
  variables {
    device_groups = {
      a = { parent = "b", serials = [] }
      b = { parent = "a", serials = [] }
    }
    templates = {}
  }
  expect_failures = [var.device_groups]
}

run "reject_blank_serial" {
  command = plan
  variables {
    device_groups = {}
    templates = { invalid = {
      name        = "test-network"
      stack       = "test-stack"
      description = "Test network"
      serials     = [""]
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
        virtual_router    = "test-vr"
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
