mock_provider "panos" {}

run "hub_and_spoke_stack_membership" {
  command = apply
  assert {
    condition = (
      module.spoke_stack.templates == tolist([
        module.spoke_template.names.template,
        module.common_template.names.template
      ]) &&
      module.hub_stack.templates == tolist([
        module.hub_template.names.template,
        module.common_template.names.template
      ])
    )
    error_message = "Each role must layer its own network above common."
  }
  assert {
    condition = (
      toset(module.spoke_template.gre_router_interfaces) == toset([
        module.spoke_template.names.subinterfaces.mgmt,
        module.spoke_template.names.tunnel_interfaces.hub
      ]) &&
      toset(module.hub_template.gre_router_interfaces) == toset([
        module.hub_template.names.subinterfaces.mgmt,
        module.hub_template.names.tunnel_interfaces.spoke_a,
        module.hub_template.names.tunnel_interfaces.spoke_b
      ]) &&
      toset(module.spoke_template.gre_router_interfaces) ==
      toset(module.spoke_template.gre_zone_interfaces) &&
      toset(module.hub_template.gre_router_interfaces) ==
      toset(module.hub_template.gre_zone_interfaces)
    )
    error_message = "GRE must retain management LAN and add the role tunnels."
  }
  assert {
    condition = (
      module.spoke_template.gre_endpoints.hub.peer_address.ip ==
      var.templates.spoke.var.hub_wan_ip &&
      module.hub_template.gre_endpoints.spoke_a.peer_address.ip ==
      var.templates.hub.var.spoke_a_wan_ip &&
      module.hub_template.gre_endpoints.spoke_b.peer_address.ip ==
      var.templates.hub.var.spoke_b_wan_ip
    )
    error_message = "Each GRE endpoint must use the configured WAN peer."
  }
  assert {
    condition = alltrue([
      for endpoint in values(module.spoke_template.gre_endpoints) : (
        endpoint.local_address.interface ==
        var.templates.spoke.var.wan_interface &&
        endpoint.local_address.ip ==
        module.spoke_template.names.variables.wan_ip &&
        endpoint.location.template.name == var.templates.spoke.name &&
        endpoint.location.template_stack == null
      )
    ])
    error_message = "Spoke GRE must use its own template and WAN variable."
  }
  assert {
    condition = alltrue(flatten([
      for locations in values(module.spoke_template.network_locations) : [
        for location in values(locations) : (
          location.template.name == var.templates.spoke.name &&
          location.template_stack == null
        )
      ]
    ]))
    error_message = "Configured role values and memberships must be preserved."
  }
  assert {
    condition = alltrue([
      for endpoint in values(module.hub_template.gre_endpoints) : (
        endpoint.local_address.interface ==
        var.templates.hub.var.wan_interface &&
        endpoint.local_address.ip ==
        module.hub_template.names.variables.wan_ip &&
        endpoint.location.template.name == var.templates.hub.name &&
        endpoint.location.template_stack == null
      )
    ])
    error_message = "Hub GRE must use its own template and WAN variable."
  }
  assert {
    condition = alltrue(flatten([
      for locations in values(module.hub_template.network_locations) : [
        for location in values(locations) : (
          location.template.name == var.templates.hub.name &&
          location.template_stack == null
        )
      ]
    ]))
    error_message = "Hub interfaces, routers and zones must be template scoped."
  }
}
