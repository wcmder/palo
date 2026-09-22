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
    tunnel_ip = {
      name     = "$tunnel_ip"
      location = { template = { name = module.templates.names.template } }
      type     = { ip_netmask = var.item.var.tunnel_ip }
    }
    gre_local_ip = {
      name     = "$gre_local_ip"
      location = { template = { name = module.templates.names.template } }
      type     = { ip_netmask = var.item.var.gre_local_ip }
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
    hub = {
      name = var.item.tunnel_interface
      location = { template = {
        name = module.templates.names.template
        vsys = "vsys1"
      } }
      ip = [{
        name = module.variables.names.tunnel_ip
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
    hub = {
      name     = "gre-to-hub"
      location = { template_stack = { name = var.stack } }
      local_address = {
        interface = var.network.wan_interface
        ip        = var.network.wan_address_reference
      }
      peer_address     = { ip = var.network.hub_wan_ip }
      tunnel_interface = module.tunnel_interfaces.names.hub
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
      module.tunnel_interfaces.names.hub,
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
      module.tunnel_interfaces.names.hub,
    ] }
  } }
}
