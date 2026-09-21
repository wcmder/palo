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

run "spoke" {
  command = apply
  module { source = "../../stacks/dev/spoke_template" }
  variables { item = {
    zone_protection_profiles = {
      wan = { name = "test-wan-protection" }
      lan = { name = "test-lan-protection" }
    }
    name        = "test-spoke01-network"
    stack       = "test-spoke01-stack"
    description = "Terraform-managed spoke"
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
    serials = ["test-serial-01"]
  } }
  assert {
    condition = (
      output.names.subinterfaces.mgmt == "ethernet1/2.10" &&
      output.names.subinterfaces.lan == "ethernet1/2.20" &&
      module.subinterfaces.assignments.mgmt.ip[0].name == "$mgmt_ip" &&
      module.subinterfaces.assignments.lan.ip[0].name == "$lan_ip" &&
      module.subinterfaces.assignments.mgmt.tag == var.item.var.mgmt_subinterface_tag &&
      module.subinterfaces.assignments.lan.tag == var.item.var.lan_subinterface_tag
    )
    error_message = "Subinterfaces must follow this template's parent, VLAN tags and IP variables."
  }
  assert {
    condition = (
      module.routers.names.mgmt == "mgmt" &&
      module.zones.names.mgmt == "mgmt" &&
      toset(module.routers.interfaces.mgmt) == toset(["ethernet1/2.10"]) &&
      toset(module.routers.interfaces.data) == toset(["ethernet1/1", "ethernet1/2.20"]) &&
      toset(module.zones.interfaces.mgmt) == toset(["ethernet1/2.10"]) &&
      toset(module.zones.interfaces.lan) == toset(["ethernet1/2.20"])
    )
    error_message = "Management and data must retain separate router and zone memberships."
  }
  assert {
    condition = (
      length(output.name_id.interfaces) == 2 && length(output.name_id.variables) == 4 &&
      output.variable_values["$lan_ip"] == "198.51.100.1/24" &&
      jsondecode(base64decode(output.name_id.routes["default"])).location.template.name == var.item.name &&
      jsondecode(base64decode(output.name_id.subinterfaces["ethernet1/2.10"])).parent == var.item.var.lan_interface
    )
    error_message = "Resources, variables and import identifiers must retain their template scope."
  }
}

run "alternate_template" {
  command = apply
  module { source = "../../stacks/dev/spoke_template" }
  variables { item = {
    zone_protection_profiles = {
      wan = { name = "test-wan-protection" }
      lan = { name = "test-lan-protection" }
    }
    name        = "test-spoke02-network"
    stack       = "test-spoke02-stack"
    description = "Terraform-managed spoke"
    var = {
      wan_interface         = "ethernet1/3"
      lan_interface         = "ethernet1/4"
      lan_subinterface_tag  = 120
      mgmt_subinterface_tag = 110
      mgmt_zone             = "management"
      mgmt_virtual_router   = "management-vr"
      wan_zone              = "wan"
      lan_zone              = "lan"
      wan_ip                = "192.0.2.6/30"
      lan_ip                = "203.0.113.1/25"
      mgmt_ip               = "203.0.113.1/24"
      default_gateway       = "192.0.2.5"
      data_virtual_router   = "spoke-vr"
    }
    serials = ["test-serial-02"]
  } }
  assert {
    condition = (
      output.names.subinterfaces.mgmt == "ethernet1/4.110" &&
      output.names.subinterfaces.lan == "ethernet1/4.120" &&
      module.subinterfaces.assignments.mgmt.ip[0].name == "$mgmt_ip" &&
      module.subinterfaces.assignments.lan.ip[0].name == "$lan_ip" &&
      module.subinterfaces.assignments.mgmt.tag == var.item.var.mgmt_subinterface_tag &&
      module.subinterfaces.assignments.lan.tag == var.item.var.lan_subinterface_tag
    )
    error_message = "Subinterfaces must follow this template's parent, VLAN tags and IP variables."
  }
  assert {
    condition = (
      module.routers.names.mgmt == "management-vr" &&
      module.zones.names.mgmt == "management" &&
      toset(module.routers.interfaces.mgmt) == toset(["ethernet1/4.110"]) &&
      toset(module.routers.interfaces.data) == toset(["ethernet1/3", "ethernet1/4.120"]) &&
      toset(module.zones.interfaces.mgmt) == toset(["ethernet1/4.110"]) &&
      toset(module.zones.interfaces.lan) == toset(["ethernet1/4.120"])
    )
    error_message = "Management and data must retain separate router and zone memberships."
  }
  assert {
    condition = (
      length(output.name_id.interfaces) == 2 && length(output.name_id.variables) == 4 &&
      output.variable_values["$lan_ip"] == "203.0.113.1/25" &&
      jsondecode(base64decode(output.name_id.routes["default"])).location.template.name == var.item.name &&
      jsondecode(base64decode(output.name_id.subinterfaces["ethernet1/4.110"])).parent == var.item.var.lan_interface
    )
    error_message = "Resources, variables and import identifiers must retain their template scope."
  }
}

run "shared_stack_explicit_variables" {
  command = apply
  module { source = "../../stacks/dev/spoke_template" }
  variables {
    item = {
      zone_protection_profiles = {
        wan = { name = "test-wan-protection" }
        lan = { name = "test-lan-protection" }
      }
      name        = "shared-network"
      stack       = "shared-stack"
      description = "Terraform-managed spoke"
      var = {
        wan_interface         = "ethernet1/1"
        lan_interface         = "ethernet1/2"
        lan_subinterface_tag  = 20
        mgmt_subinterface_tag = 10
        mgmt_zone             = "mgmt"
        mgmt_virtual_router   = "mgmt"
        wan_zone              = "wan"
        lan_zone              = "lan"
        wan_ip                = "None"
        lan_ip                = "None"
        mgmt_ip               = "None"
        default_gateway       = "None"
        data_virtual_router   = "spoke-vr"
      }
      serials = ["serial-a", "serial-b"]

    }
  }
  assert {
    condition = alltrue([
      for name, value in {
        "$wan_ip"          = "None"
        "$lan_ip"          = "None"
        "$mgmt_ip"         = "None"
        "$default_gateway" = "None"
      } : output.variable_values[name] == value
    ])
    error_message = "Unassigned template variables must pass through as None without appending a prefix."
  }
  assert {
    condition     = length(output.name_id.templates) == 1 && length(output.name_id.template_stacks) == 1 && length(var.item.serials) == 2
    error_message = "Both serials must share one template and stack."
  }
}

run "reject_same_interface" {
  command = plan
  module { source = "../../stacks/dev/spoke_template" }
  variables {
    item = {
      zone_protection_profiles = {
        wan = { name = "test-wan-protection" }
        lan = { name = "test-lan-protection" }
      }
      name        = "bad"
      serials     = []
      stack       = "bad-stack"
      description = "Terraform-managed spoke"
      var = {
        wan_interface         = "ethernet1/1"
        lan_interface         = "ethernet1/1"
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
  expect_failures = [var.item]
}

run "gateway_validation_deferred_to_provider" {
  command = plan
  module { source = "../../stacks/dev/spoke_template" }
  variables {
    item = {
      zone_protection_profiles = {
        wan = { name = "test-wan-protection" }
        lan = { name = "test-lan-protection" }
      }
      name        = "bad"
      serials     = []
      stack       = "bad-stack"
      description = "Terraform-managed spoke"
      var = {
        wan_interface         = "ethernet1/1"
        lan_interface         = "ethernet1/2"
        lan_subinterface_tag  = 20
        mgmt_subinterface_tag = 10
        mgmt_zone             = "mgmt"
        mgmt_virtual_router   = "mgmt"
        wan_zone              = "wan"
        lan_zone              = "lan"
        wan_ip                = "10.0.1.2/24"
        default_gateway       = "10.0.2.1"
        lan_ip                = "198.51.100.1/24"
        mgmt_ip               = "203.0.113.1/24"
        data_virtual_router   = "spoke-vr"
      }
    }
  }
  assert {
    condition     = output.variable_values["$default_gateway"] == "10.0.2.1"
    error_message = "Gateway configuration must pass through without imposing a same-subnet convention."
  }
}

run "explicit_values_and_extra_fields" {
  command = plan
  module { source = "../../stacks/dev/spoke_template" }
  variables {
    item = {
      zone_protection_profiles = {
        wan = { name = "test-wan-protection" }
        lan = { name = "test-lan-protection" }
      }
      name        = "example"
      serials     = []
      stack       = "example-stack"
      description = "Terraform-managed spoke"
      var = {
        wan_interface         = "ethernet1/1"
        lan_interface         = "ethernet1/2"
        lan_subinterface_tag  = 20
        mgmt_subinterface_tag = 10
        mgmt_zone             = "mgmt"
        mgmt_virtual_router   = "mgmt"
        wan_zone              = "untrust"
        lan_zone              = "trust"
        wan_ip                = "192.0.2.2/30"
        future_setting        = "preserved"
        lan_ip                = "198.51.100.1/24"
        mgmt_ip               = "203.0.113.1/24"
        default_gateway       = "192.0.2.1"
        data_virtual_router   = "spoke-vr"
      }
    }
  }
  assert {
    condition     = var.item.var.wan_ip == "192.0.2.2/30" && var.item.var.wan_zone == "untrust" && var.item.var.lan_zone == "trust" && var.item.var.future_setting == "preserved"
    error_message = "Explicit values and future input fields must pass through unchanged."
  }
}
