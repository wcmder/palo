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
        module.common_template.names.subinterfaces.mgmt,
        module.spoke_template.names.interfaces.hub
      ]) &&
      toset(module.hub_template.gre_router_interfaces) == toset([
        module.common_template.names.subinterfaces.mgmt,
        module.hub_template.names.interfaces.spoke_a,
        module.hub_template.names.interfaces.spoke_b
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
      module.spoke_template.gre_endpoints.hub.peer_address.ip == var.templates.spoke.var.hub_wan_ip &&
      module.hub_template.gre_endpoints.spoke_a.peer_address.ip == var.templates.hub.var.spoke_a_wan_ip &&
      module.hub_template.gre_endpoints.spoke_b.peer_address.ip == var.templates.hub.var.spoke_b_wan_ip
    )
    error_message = "Each GRE endpoint must use the configured WAN peer."
  }
  assert {
    condition = alltrue([
      for endpoint in concat(
        values(module.spoke_template.gre_endpoints),
        values(module.hub_template.gre_endpoints)
        ) : (
        endpoint.local_address.interface ==
        var.templates.common.var.wan_interface &&
        endpoint.local_address.ip ==
        module.common_template.names.variables.wan_ip
      )
    ])
    error_message = "GRE sources must reference the WAN interface variable."
  }

}
