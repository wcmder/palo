mock_provider "panos" {}

run "multiple_variables_and_routes" {
  command = apply
  module { source = "./tests/fixtures/all" }
  assert {
    condition     = length(output.template_variable) == 2 && length(output.static_route_ipv4) == 2
    error_message = "Both new feature modules must create multiple resources."
  }
  assert {
    condition     = jsondecode(base64decode(output.static_route_ipv4["default"])).virtual_router == "example-vr"
    error_message = "Route import identities must include their parent virtual router."
  }
  assert {
    condition     = jsondecode(base64decode(output.template_variable["$wan_ip"])).location.template.name == "example-template"
    error_message = "Template variable identity must retain its template scope."
  }
}

run "two_spokes" {
  command = apply
  module { source = "../../stacks/lab/spoke_template" }
  variables {
    items = {
      spoke01 = {
        name        = "test-spoke01-network"
        stack       = "test-spoke01-stack"
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
        serials = ["test-serial-01"]
      }
      spoke02 = {
        name        = "test-spoke02-network"
        stack       = "test-spoke02-stack"
        description = "Terraform-managed spoke"
        var = {
          wan_interface     = "ethernet1/3"
          lan_interface     = "ethernet1/4"
          wan_zone          = "wan"
          lan_zone          = "lan"
          wan_ip            = "192.0.2.6"
          wan_prefix_length = 30
          lan_ip            = "203.0.113.1"
          lan_prefix_length = 25
          default_gateway   = "192.0.2.5"
          virtual_router    = "spoke-vr"
        }
        serials = ["test-serial-02"]
      }
    }
  }
  assert {
    condition     = length(output.name_id.interfaces.spoke01) == 2 && length(output.name_id.variables.spoke02) == 3
    error_message = "Spokes must retain separate templates, interfaces and variables."
  }
  assert {
    condition     = output.variable_values["spoke01"]["$wan_ip"] == "192.0.2.2/30" && output.variable_values["spoke02"]["$lan_ip"] == "203.0.113.1/25"
    error_message = "Native template variables must retain the host IP and supplied prefix."
  }
  assert {
    condition     = output.variable_values["spoke02"]["$default_gateway"] == "192.0.2.5" && output.names.interfaces.spoke02.wan == "ethernet1/3"
    error_message = "The second spoke must use its own gateway and interface name."
  }
  assert {
    condition     = jsondecode(base64decode(output.name_id.routes.spoke02["default"])).location.template.name == "test-spoke02-network"
    error_message = "The default route must be scoped to the correct spoke template."
  }
}

run "shared_stack_unassigned_variables" {
  command = apply
  module { source = "../../stacks/lab/spoke_template" }
  variables {
    items = {
      shared = {
        name        = "shared-network"
        stack       = "shared-stack"
        description = "Terraform-managed spoke"
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
          virtual_router    = "spoke-vr"
        }
        serials = ["serial-a", "serial-b"]

      }
    }
  }
  assert {
    condition = alltrue([
      for name in ["$wan_ip", "$lan_ip", "$default_gateway"] :
      output.variable_values["shared"][name] == "None"
    ])
    error_message = "Unassigned variables must retain the literal Panorama None value."
  }
  assert {
    condition     = length(output.name_id.templates) == 1 && length(output.name_id.template_stacks) == 1 && length(var.items.shared.serials) == 2
    error_message = "Both serials must share one template and stack."
  }
}



run "reject_same_interface" {
  command = plan
  module { source = "../../stacks/lab/spoke_template" }
  variables {
    items = {
      bad = {
        name        = "bad"
        serials     = []
        stack       = "bad-stack"
        description = "Terraform-managed spoke"
        var = {
          wan_interface     = "ethernet1/1"
          lan_interface     = "ethernet1/1"
          wan_zone          = "wan"
          lan_zone          = "lan"
          wan_ip            = "None"
          wan_prefix_length = null
          lan_ip            = "None"
          lan_prefix_length = null
          default_gateway   = "None"
          virtual_router    = "spoke-vr"
        }
      }
    }
  }
  expect_failures = [var.items]
}

run "reject_off_subnet_gateway" {
  command = plan
  module { source = "../../stacks/lab/spoke_template" }
  variables {
    items = {
      bad = {
        name        = "bad"
        serials     = []
        stack       = "bad-stack"
        description = "Terraform-managed spoke"
        var = {
          wan_interface     = "ethernet1/1"
          lan_interface     = "ethernet1/2"
          wan_zone          = "wan"
          lan_zone          = "lan"
          wan_ip            = "10.0.1.2"
          wan_prefix_length = 24
          default_gateway   = "10.0.2.1"
          lan_ip            = "None"
          lan_prefix_length = null
          virtual_router    = "spoke-vr"
        }
      }
    }
  }
  expect_failures = [var.items]
}

run "reject_unassigned_ip_with_prefix" {
  command = plan
  module { source = "../../stacks/lab/spoke_template" }
  variables {
    items = {
      bad = {
        name        = "bad"
        serials     = []
        stack       = "bad-stack"
        description = "Terraform-managed spoke"
        var = {
          wan_interface     = "ethernet1/1"
          lan_interface     = "ethernet1/2"
          wan_zone          = "wan"
          lan_zone          = "lan"
          wan_prefix_length = 24
          wan_ip            = "None"
          lan_ip            = "None"
          lan_prefix_length = null
          default_gateway   = "None"
          virtual_router    = "spoke-vr"
        }
      }
    }
  }
  expect_failures = [var.items]
}

run "reject_assigned_ip_without_prefix" {
  command = plan
  module { source = "../../stacks/lab/spoke_template" }
  variables {
    items = {
      bad = {
        name        = "bad"
        serials     = []
        stack       = "bad-stack"
        description = "Terraform-managed spoke"
        var = {
          wan_interface     = "ethernet1/1"
          lan_interface     = "ethernet1/2"
          wan_zone          = "wan"
          lan_zone          = "lan"
          wan_ip            = "10.0.1.2"
          wan_prefix_length = null
          lan_ip            = "None"
          lan_prefix_length = null
          default_gateway   = "None"
          virtual_router    = "spoke-vr"
        }
      }
    }
  }
  expect_failures = [var.items]
}

run "explicit_values_and_extra_fields" {
  command = plan
  module { source = "../../stacks/lab/spoke_template" }
  variables {
    items = {
      example = {
        name        = "example"
        serials     = []
        stack       = "example-stack"
        description = "Terraform-managed spoke"
        var = {
          wan_interface     = "ethernet1/1"
          lan_interface     = "ethernet1/2"
          wan_zone          = "untrust"
          lan_zone          = "trust"
          wan_ip            = "None"
          future_setting    = "preserved"
          wan_prefix_length = null
          lan_ip            = "None"
          lan_prefix_length = null
          default_gateway   = "None"
          virtual_router    = "spoke-vr"
        }
      }
    }
  }
  assert {
    condition     = var.items.example.var.wan_ip == "None" && var.items.example.var.wan_zone == "untrust" && var.items.example.var.lan_zone == "trust" && var.items.example.var.future_setting == "preserved"
    error_message = "Explicit values and future input fields must pass through unchanged."
  }
}
