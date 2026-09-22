mock_provider "panos" {}

run "multiple_variables_and_routes" {
  command = apply
  module { source = "./tests/fixtures/all" }
  assert {
    condition     = length(output.template_variable) == 2 && length(output.static_route_ipv4) == 2
    error_message = "Both new feature modules must create multiple resources."
  }
  assert {
    condition     = output.static_route_ipv4["default"] == "default"
    error_message = "Route names must retain their logical keys."
  }
  assert {
    condition     = output.template_variable["wan"] == "$wan_ip"
    error_message = "Template variable names must retain their logical keys."
  }
}

run "spoke" {
  command = apply
  module { source = "../../stacks/dev/templates/shared/common" }
  variables { item = {
    zone_protection_profiles = {
      wan = { name = "test-wan-protection" }
      lan = { name = "test-lan-protection" }
    }
    name = "test-spoke01-network"

    description = "Terraform-managed spoke"
    interface_management_profiles = {
      wan  = { name = "wan-ping", ping = true }
      lan  = { name = "lan-ping", ping = true }
      mgmt = { name = "mgmt-ping", ping = true }
    }
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

  } }
  assert {
    condition = (
      length(output.names.interface_management_profiles) == 3 &&
      module.interfaces.management_profiles.wan ==
      var.item.interface_management_profiles.wan.name &&
      module.subinterfaces.management_profiles.lan ==
      var.item.interface_management_profiles.lan.name &&
      module.subinterfaces.management_profiles.mgmt ==
      var.item.interface_management_profiles.mgmt.name &&
      module.interfaces.management_profiles.lan == null &&
      alltrue([
        for p in values(module.interface_management_profiles.settings) :
        p.ping && !p.ssh && !p.https && !p.http && !p.telnet && !p.snmp &&
        !p.http_ocsp && !p.response_pages && !p.userid_service &&
        !p.userid_syslog_listener_ssl && !p.userid_syslog_listener_udp
      ])
    )
    error_message = "Only ping must be enabled on each zone's interface."
  }
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
      length(output.names.interfaces) == 2 && length(output.names.variables) == 4 &&
      output.variable_values["$lan_ip"] == "198.51.100.1/24" &&
      module.routes.locations.default.template.name == var.item.name &&
      module.subinterfaces.names.mgmt == "${var.item.var.lan_interface}.${var.item.var.mgmt_subinterface_tag}"
    )
    error_message = "Resource names, variables and routes must follow template inputs."
  }
}

run "alternate_template" {
  command = apply
  module { source = "../../stacks/dev/templates/shared/common" }
  variables { item = {
    zone_protection_profiles = {
      wan = { name = "test-wan-protection" }
      lan = { name = "test-lan-protection" }
    }
    name = "test-spoke02-network"

    description = "Terraform-managed spoke"
    interface_management_profiles = {
      wan  = { name = "external-ping", ping = true }
      lan  = { name = "internal-ping", ping = true }
      mgmt = { name = "admin-ping", ping = true }
    }
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

  } }
  assert {
    condition = (
      module.interfaces.management_profiles.wan == "external-ping" &&
      module.subinterfaces.management_profiles.lan == "internal-ping" &&
      module.subinterfaces.management_profiles.mgmt == "admin-ping" &&
      module.interface_management_profiles.locations.mgmt.template.name == var.item.name
    )
    error_message = "Profile names and scope must follow the template input."
  }
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
      length(output.names.interfaces) == 2 && length(output.names.variables) == 4 &&
      output.variable_values["$lan_ip"] == "203.0.113.1/25" &&
      module.routes.locations.default.template.name == var.item.name &&
      module.subinterfaces.names.mgmt == "${var.item.var.lan_interface}.${var.item.var.mgmt_subinterface_tag}"
    )
    error_message = "Resource names, variables and routes must follow template inputs."
  }
}

run "shared_stack_explicit_variables" {
  command = apply
  module { source = "../../stacks/dev/templates/shared/common" }
  variables {
    item = {
      zone_protection_profiles = {
        wan = { name = "test-wan-protection" }
        lan = { name = "test-lan-protection" }
      }
      name = "shared-network"

      description = "Terraform-managed spoke"
      interface_management_profiles = {
        wan  = { name = "wan-ping", ping = true }
        lan  = { name = "lan-ping", ping = true }
        mgmt = { name = "mgmt-ping", ping = true }
      }
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
    condition     = length(output.names.templates) == 1
    error_message = "Network configuration must create one reusable template."
  }
}

run "reject_same_interface" {
  command = plan
  module { source = "../../stacks/dev/templates/shared/common" }
  variables {
    item = {
      zone_protection_profiles = {
        wan = { name = "test-wan-protection" }
        lan = { name = "test-lan-protection" }
      }
      name = "bad"


      description = "Terraform-managed spoke"
      interface_management_profiles = {
        wan  = { name = "wan-ping", ping = true }
        lan  = { name = "lan-ping", ping = true }
        mgmt = { name = "mgmt-ping", ping = true }
      }
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
  module { source = "../../stacks/dev/templates/shared/common" }
  variables {
    item = {
      zone_protection_profiles = {
        wan = { name = "test-wan-protection" }
        lan = { name = "test-lan-protection" }
      }
      name = "bad"


      description = "Terraform-managed spoke"
      interface_management_profiles = {
        wan  = { name = "wan-ping", ping = true }
        lan  = { name = "lan-ping", ping = true }
        mgmt = { name = "mgmt-ping", ping = true }
      }
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
  module { source = "../../stacks/dev/templates/shared/common" }
  variables {
    item = {
      zone_protection_profiles = {
        wan = { name = "test-wan-protection" }
        lan = { name = "test-lan-protection" }
      }
      name = "example"


      description = "Terraform-managed spoke"
      interface_management_profiles = {
        wan  = { name = "wan-ping", ping = true }
        lan  = { name = "lan-ping", ping = true }
        mgmt = { name = "mgmt-ping", ping = true }
      }
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
