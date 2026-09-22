mock_provider "panos" {}

run "gre_endpoint_selection" {
  command = apply
  module { source = "../../stacks/modules/panos/network/gre_tunnel" }
  variables {
    items = {
      hub = {
        name             = "test-gre-hub"
        location         = { template_stack = { name = "test-stack" } }
        local_address    = { interface = "ethernet1/3", ip = "192.0.2.2" }
        peer_address     = { ip = "198.51.100.2" }
        tunnel_interface = "tunnel.7"
        keep_alive       = { enable = true }
      }
    }
  }
  assert {
    condition = (
      panos_gre_tunnel.this["hub"].local_address.interface == "ethernet1/3" &&
      panos_gre_tunnel.this["hub"].local_address.ip == "192.0.2.2" &&
      panos_gre_tunnel.this["hub"].peer_address.ip == "198.51.100.2" &&
      panos_gre_tunnel.this["hub"].tunnel_interface == "tunnel.7" &&
      panos_gre_tunnel.this["hub"].location.template_stack.name == "test-stack"
    )
    error_message = "GRE must retain its source, peer, interface and scope."
  }
}

run "tunnel_interface_address" {
  command = apply
  module { source = "../../stacks/modules/panos/network/tunnel_interface" }
  variables {
    items = {
      hub = {
        name     = "tunnel.7"
        location = { template = { name = "test-spoke", vsys = "vsys1" } }
        ip       = [{ name = "192.0.2.9/30" }]
        mtu      = 1476
      }
    }
  }
  assert {
    condition = (
      output.names.hub == "tunnel.7" &&
      panos_tunnel_interface.this["hub"].ip[0].name == "192.0.2.9/30" &&
      panos_tunnel_interface.this["hub"].mtu == 1476
    )
    error_message = "Tunnel interfaces must retain configured addressing."
  }
}
