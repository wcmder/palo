module "templates" {
  source = "../../../../modules/panos/panorama/template"
  items = { template = {
    name         = var.item.name
    description  = var.item.description
    default_vsys = "vsys1"
    location     = { panorama = {} }
  } }
}

module "variables" {
  source = "../../../../modules/panos/panorama/template_variable"
  items = {
    spoke_a_tunnel_ip = {
      name     = "$spoke_a_tunnel_ip"
      location = { template = { name = module.templates.names.template } }
      type     = { ip_netmask = var.item.var.spoke_a_tunnel_ip }
    }
    spoke_b_tunnel_ip = {
      name     = "$spoke_b_tunnel_ip"
      location = { template = { name = module.templates.names.template } }
      type     = { ip_netmask = var.item.var.spoke_b_tunnel_ip }
    }
  }
}

module "management_profiles" {
  source = "../../../../modules/panos/network/interface_management_profile"
  items = { tunnel = {
    name     = "gre-ping"
    location = { template = { name = module.templates.names.template } }
    ping     = true
  } }
}

module "tunnel_interfaces" {
  source = "../../../../modules/panos/network/tunnel_interface"
  items = {
    spoke_a = {
      name = var.item.spoke_a_interface
      location = { template = {
        name = module.templates.names.template
        vsys = "vsys1"
      } }
      ip = [{
        name = module.variables.names.spoke_a_tunnel_ip
      }]
      mtu                          = 1476
      interface_management_profile = module.management_profiles.names.tunnel
    }
    spoke_b = {
      name = var.item.spoke_b_interface
      location = { template = {
        name = module.templates.names.template
        vsys = "vsys1"
      } }
      ip = [{
        name = module.variables.names.spoke_b_tunnel_ip
      }]
      mtu                          = 1476
      interface_management_profile = module.management_profiles.names.tunnel
    }
  }
}

# Stack scope can reference interfaces inherited from different templates.
module "gre_tunnels" {
  source = "../../../../modules/panos/network/gre_tunnel"
  items = {
    spoke_a = {
      name     = "gre-to-spoke-a"
      location = { template_stack = { name = var.stack } }
      local_address = {
        interface = var.network.wan_interface
        ip        = var.network.wan_address_reference
      }
      peer_address     = { ip = var.network.spoke_a_wan_ip }
      tunnel_interface = module.tunnel_interfaces.names.spoke_a
      keep_alive       = { enable = true }
    }
    spoke_b = {
      name     = "gre-to-spoke-b"
      location = { template_stack = { name = var.stack } }
      local_address = {
        interface = var.network.wan_interface
        ip        = var.network.wan_address_reference
      }
      peer_address     = { ip = var.network.spoke_b_wan_ip }
      tunnel_interface = module.tunnel_interfaces.names.spoke_b
      keep_alive       = { enable = true }
    }
  }
}

module "routers" {
  source = "../../../../modules/panos/network/virtual_router"
  items = { mgmt = {
    name     = var.network.mgmt_virtual_router
    location = { template_stack = { name = var.stack } }
    interfaces = [
      var.mgmt_interface,
      module.tunnel_interfaces.names.spoke_a,
      module.tunnel_interfaces.names.spoke_b,
    ]
  } }
}

module "zones" {
  source = "../../../../modules/panos/network/zone"
  items = { mgmt = {
    name     = var.network.mgmt_zone
    location = { template_stack = { name = var.stack, vsys = "vsys1" } }
    network = { layer3 = [
      var.mgmt_interface,
      module.tunnel_interfaces.names.spoke_a,
      module.tunnel_interfaces.names.spoke_b,
    ] }
  } }
}
