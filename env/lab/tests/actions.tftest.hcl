# Mocked plan only: no commit/push invocation and no Panorama connection.
mock_provider "panos" {}

run "push_only_assigned_spokes" {
  command = plan
  variables {
    sites = {}
    spokes = {
      unassigned = {
        policy = {
          device_group = "test-shared"
        }
        template = {
          name        = "test-unassigned-network"
          stack       = "test-unassigned-stack"
          description = "Terraform-managed spoke"
          var = {
            wan_interface     = "ethernet1/1"
            lan_interface     = "ethernet1/2"
            wan_zone          = "wan"
            lan_zone          = "lan"
            wan_ip            = "192.0.2.2"
            wan_prefix_length = 30
            lan_ip            = "198.51.100.1"
            lan_prefix_length = 24
            default_gateway   = "192.0.2.1"
            virtual_router    = "spoke-vr"
          }
        }
      }
      assigned = {
        policy = {
          device_group = "test-shared"
        }
        template = {
          name        = "test-assigned-network"
          stack       = "test-assigned-stack"
          description = "Terraform-managed spoke"
          var = {
            wan_interface     = "ethernet1/1"
            lan_interface     = "ethernet1/2"
            wan_zone          = "wan"
            lan_zone          = "lan"
            wan_ip            = "192.0.2.6"
            wan_prefix_length = 30
            lan_ip            = "203.0.113.1"
            lan_prefix_length = 24
            default_gateway   = "192.0.2.5"
            virtual_router    = "spoke-vr"
          }
        }
        serials = ["test-serial-01", "test-serial-02"]
      }
    }
  }
  assert {
    condition     = keys(module.deployment.name_id.commit) == ["assigned", "unassigned"] && module.deployment.name_id.commit.assigned == "action.panos_commit.this[\"assigned\"]"
    error_message = "Every target must expose a correctly indexed commit invocation address."
  }
  assert {
    condition     = keys(module.deployment.name_id.push) == ["assigned"]
    error_message = "Unassigned spokes must not expose a push action."
  }
  assert {
    condition     = keys(module.deployment.name_id.commit_and_push) == ["assigned"] && module.deployment.name_id.commit_and_push.assigned == "action.panos_commit.commit_and_push[\"assigned\"]"
    error_message = "Combined actions must target assigned spokes only and expose their invocation addresses."
  }
  assert {
    condition     = module.deployment.push_targets.assigned.serials == tolist(["test-serial-01", "test-serial-02"])
    error_message = "Push targets must retain the explicitly assigned serials."
  }
}

run "reject_blank_serial" {
  command = plan
  variables {
    sites = {}
    spokes = {
      invalid = {
        policy = {
          device_group = "test-invalid"
        }
        template = {
          name        = "test-invalid-network"
          stack       = "test-invalid-stack"
          description = "Terraform-managed spoke"
          var = {
            wan_interface     = "ethernet1/1"
            lan_interface     = "ethernet1/2"
            wan_zone          = "wan"
            lan_zone          = "lan"
            wan_ip            = "192.0.2.2"
            wan_prefix_length = 30
            lan_ip            = "198.51.100.1"
            lan_prefix_length = 24
            default_gateway   = "192.0.2.1"
            virtual_router    = "spoke-vr"
          }
        }
        serials = [""]
      }
    }
  }
  expect_failures = [var.spokes]
}
