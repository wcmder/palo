mock_provider "panos" {}

run "spoke_bgp" {
  command = apply
  module { source = "../../stacks/dev/templates/spoke/network" }
  variables {
    item = {
      name        = "test-spoke-bgp"
      description = "BGP composition test"
      interface_management_profiles = {
        wan  = { name = "wan-ping", ping = true }
        lan  = { name = "lan-ping", ping = true }
        mgmt = { name = "mgmt-ping", ping = true }
      }
      zone_protection_profiles = {
        wan = { name = "wan-protection" }
        lan = { name = "lan-protection" }
      }
    }
    network = {
      local_bgp_asn         = "65001"
      bgp_router_id         = "192.0.2.10"
      remote_bgp_asn        = "65003"
      remote_bgp_peer_ip    = "10.255.13.3"
      bgp_password          = "example-bgp-password"
      tunnel_interface      = "tunnel.700"
      data_virtual_router   = "data"
      mgmt_virtual_router   = "mgmt"
      wan_interface         = "ethernet1/1"
      lan_interface         = "ethernet1/2"
      lan_subinterface_tag  = 10
      mgmt_subinterface_tag = 20
      mgmt_zone             = "mgmt"
      wan_zone              = "wan"
      lan_zone              = "lan"
      wan_ip                = "None"
      default_gateway       = "None"
      lan_ip                = "None"
      mgmt_ip               = "None"

      hub_wan_ip = "10.0.3.2"
      tunnel_ip  = "None"
    }
  }
  assert {
    condition = (
      module.routers.routing.mgmt.bgp.enable &&
      module.routers.routing.mgmt.bgp.install_route &&
      module.routers.routing.mgmt.bgp.local_as == "$local_bgp_asn" &&
      output.variable_values["$local_bgp_asn"] ==
      var.network.local_bgp_asn &&
      module.routers.routing.mgmt.bgp.router_id == "$bgp_router_id" &&
      length(module.routers.routing.mgmt.bgp.peer_group) == 1 &&
      module.routers.routing.data == null
    )
    error_message = "BGP must run only on mgmt with the expected peers."
  }
  assert {
    condition = (
      module.routers.routing.mgmt.bgp.peer_group[0].type.ebgp != null &&
      module.routers.routing.mgmt.bgp.peer_group[0].peer[0].local_address == {
        interface = var.network.tunnel_interface
        ip        = "$tunnel_ip"
      } &&
      module.routers.routing.mgmt.bgp.peer_group[0].peer[0].peer_as ==
      "$remote_bgp_asn" &&
      module.routers.routing.mgmt.bgp.peer_group[0].peer[0].peer_address.ip ==
      "$remote_bgp_peer_ip" &&
      module.routers.routing.mgmt.bgp.auth_profile[0].secret ==
      var.network.bgp_password &&
      module.routers.routing.mgmt.bgp.peer_group[0].peer[0].connection_options[
        "authentication"
      ] ==
      module.routers.routing.mgmt.bgp.auth_profile[0].name
    )
    error_message = "Peer hub must use its tunnel, variables and auth."
  }
  assert {
    condition = (
      module.routers.routing.mgmt.redist_profile[0].filter.type ==
      tolist(["connect"]) &&
      module.routers.routing.mgmt.redist_profile[0].filter.interface ==
      tolist([module.subinterfaces.names.mgmt]) &&
      module.routers.routing.mgmt.bgp.redist_rules[0].name ==
      module.routers.routing.mgmt.redist_profile[0].name
    )
    error_message = "Redistribution must include only connected mgmt routes."
  }
}

run "hub_bgp" {
  command = apply
  module { source = "../../stacks/dev/templates/hub/network" }
  variables {
    item = {
      name        = "test-hub-bgp"
      description = "BGP composition test"
      interface_management_profiles = {
        wan  = { name = "wan-ping", ping = true }
        lan  = { name = "lan-ping", ping = true }
        mgmt = { name = "mgmt-ping", ping = true }
      }
      zone_protection_profiles = {
        wan = { name = "wan-protection" }
        lan = { name = "lan-protection" }
      }
    }
    network = {
      local_bgp_asn              = "65001"
      bgp_router_id              = "192.0.2.10"
      spoke_a_remote_bgp_asn     = "65003"
      spoke_a_remote_bgp_peer_ip = "10.255.13.1"
      spoke_a_bgp_password       = "example-bgp-password"
      spoke_b_remote_bgp_asn     = "65003"
      spoke_b_remote_bgp_peer_ip = "10.255.23.2"
      spoke_b_bgp_password       = "example-bgp-password"
      spoke_a_interface          = "tunnel.701"
      spoke_b_interface          = "tunnel.702"
      data_virtual_router        = "data"
      mgmt_virtual_router        = "mgmt"
      wan_interface              = "ethernet1/1"
      lan_interface              = "ethernet1/2"
      lan_subinterface_tag       = 10
      mgmt_subinterface_tag      = 20
      mgmt_zone                  = "mgmt"
      wan_zone                   = "wan"
      lan_zone                   = "lan"
      wan_ip                     = "None"
      default_gateway            = "None"
      lan_ip                     = "None"
      mgmt_ip                    = "None"
      spoke_a_wan_ip             = "10.0.1.2"
      spoke_b_wan_ip             = "10.0.2.2"
      spoke_a_tunnel_ip          = "None"
      spoke_b_tunnel_ip          = "None"
    }
  }
  assert {
    condition = (
      module.routers.routing.mgmt.bgp.enable &&
      module.routers.routing.mgmt.bgp.install_route &&
      module.routers.routing.mgmt.bgp.local_as == "$local_bgp_asn" &&
      output.variable_values["$local_bgp_asn"] ==
      var.network.local_bgp_asn &&
      module.routers.routing.mgmt.bgp.router_id == "$bgp_router_id" &&
      length(module.routers.routing.mgmt.bgp.peer_group) == 2 &&
      module.routers.routing.data == null
    )
    error_message = "BGP must run only on mgmt with the expected peers."
  }
  assert {
    condition = (
      module.routers.routing.mgmt.bgp.peer_group[0].type.ebgp != null &&
      module.routers.routing.mgmt.bgp.peer_group[0].peer[0].local_address == {
        interface = var.network.spoke_a_interface
        ip        = "$spoke_a_tunnel_ip"
      } &&
      module.routers.routing.mgmt.bgp.peer_group[0].peer[0].peer_as ==
      "$spoke_a_remote_bgp_asn" &&
      module.routers.routing.mgmt.bgp.peer_group[0].peer[0].peer_address.ip ==
      "$spoke_a_remote_bgp_peer_ip" &&
      module.routers.routing.mgmt.bgp.auth_profile[0].secret ==
      var.network.spoke_a_bgp_password &&
      module.routers.routing.mgmt.bgp.peer_group[0].peer[0].connection_options[
        "authentication"
      ] ==
      module.routers.routing.mgmt.bgp.auth_profile[0].name
    )
    error_message = "Peer spoke_a must use its tunnel, variables and auth."
  }
  assert {
    condition = (
      module.routers.routing.mgmt.bgp.peer_group[1].type.ebgp != null &&
      module.routers.routing.mgmt.bgp.peer_group[1].peer[0].local_address == {
        interface = var.network.spoke_b_interface
        ip        = "$spoke_b_tunnel_ip"
      } &&
      module.routers.routing.mgmt.bgp.peer_group[1].peer[0].peer_as ==
      "$spoke_b_remote_bgp_asn" &&
      module.routers.routing.mgmt.bgp.peer_group[1].peer[0].peer_address.ip ==
      "$spoke_b_remote_bgp_peer_ip" &&
      module.routers.routing.mgmt.bgp.auth_profile[1].secret ==
      var.network.spoke_b_bgp_password &&
      module.routers.routing.mgmt.bgp.peer_group[1].peer[0].connection_options[
        "authentication"
      ] ==
      module.routers.routing.mgmt.bgp.auth_profile[1].name
    )
    error_message = "Peer spoke_b must use its tunnel, variables and auth."
  }
  assert {
    condition = (
      module.routers.routing.mgmt.redist_profile[0].filter.type ==
      tolist(["connect"]) &&
      module.routers.routing.mgmt.redist_profile[0].filter.interface ==
      tolist([module.subinterfaces.names.mgmt]) &&
      module.routers.routing.mgmt.bgp.redist_rules[0].name ==
      module.routers.routing.mgmt.redist_profile[0].name
    )
    error_message = "Redistribution must include only connected mgmt routes."
  }
}

