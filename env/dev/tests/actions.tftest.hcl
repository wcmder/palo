mock_provider "panos" {}

variables {
  templates = {
    common = {
      name = "spoke-network"

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

    }
  }
  template_stacks = { spoke = {
    name        = "spoke-stack"
    description = "Test stack"
    templates   = ["common"]
    serials     = ["PA_A_SERIAL", "PA_B_SERIAL", "PA_C_SERIAL"]
  } }


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
      parent_a = {
        device_group = "parent_a"
        serials      = []
      }
      parent_b = {
        device_group = "parent_b"
        parent       = null
        serials      = []
      }
      branches_a = {
        device_group = "branch-production"
        parent       = "parent_a"
        serials      = ["A", "H"]
      }
      branches_b = {
        device_group = "branches_b"
        parent       = "parent_b"
        serials      = ["B"]
      }
    }
    templates = {
      spoke = {
        templates = ["test-network", "shared-common"]
        stack     = "test-stack"
        serials   = ["A", "B"]
      }
      hub = {
        templates = ["hub-network", "shared-common"]
        stack     = "hub-stack"
        serials   = ["H"]
      }
    }
  }


  assert {
    condition = (
      output.deployment_items["branches_a/spoke"].templates ==
      ["test-network", "shared-common"] &&
      output.deployment_items["branches_a/hub"].templates ==
      ["hub-network", "shared-common"]
    )
    error_message = "Commit targets must include every referenced template."
  }
  assert {
    condition     = keys(output.push_targets) == ["branches_a/hub", "branches_a/spoke", "branches_b/spoke"]
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
    condition     = output.deployment_items["branches_a/spoke"].device_groups == tolist(["parent_a", "branch-production"])
    error_message = "Scoped commits must include the inherited parent policy."
  }
}

run "policy_push_without_templates" {
  command = plan
  module { source = "../../stacks/modules/panos/operations/commit_push" }
  variables {
    device_groups = { branch = { device_group = "branch", serials = ["A"] }, unused = { device_group = "unused", serials = [] } }
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
    device_groups = { parent = { device_group = "parent", serials = [] }, bad = { device_group = "bad", parent = "missing", serials = [] } }

  }
  expect_failures = [var.device_groups]
}

run "reject_hierarchy_cycle" {
  command = plan
  variables {
    device_groups = {
      parent = {
        device_group = "parent"
        serials      = []
      }
      a = {
        device_group = "a"
        parent       = "b"
        serials      = []
      }
      b = {
        device_group = "b"
        parent       = "a"
        serials      = []
      }
    }

  }
  expect_failures = [var.device_groups]
}

run "reject_blank_serial" {
  command = plan
  variables {
    device_groups = { parent = { device_group = "parent", serials = [] } }
    template_stacks = { spoke = {
      name        = "test-stack"
      description = "Test stack"
      templates   = ["common"]
      serials     = [""]
    } }
  }
  expect_failures = [var.template_stacks]
}

run "shared_actions_template_only" {
  command = plan
  module { source = "../../stacks/modules/panos/operations/commit_push" }
  variables {
    device_groups = {}
    templates = {
      common = { templates = ["network"], stack = "network-stack", serials = ["A"] }
      unused = { templates = ["unused"], stack = "unused-stack", serials = [] }
    }
  }
  assert {
    condition     = keys(output.template_push_items) == ["common"] && length(output.policy_push_items) == 0 && length(output.deployment_items) == 0
    error_message = "Template-only actions must exist without device groups and exclude empty assignments."
  }
}
