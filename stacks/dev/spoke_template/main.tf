module "templates" {
  source = "../../modules/panos/panorama/template"
  items = { template = {
    name         = var.item.name
    description  = var.item.description
    default_vsys = "vsys1"
    location     = { panorama = {} }
  } }
}

module "template_stacks" {
  source = "../../modules/panos/panorama/template_stack"
  items = { template = {
    name         = var.item.stack
    description  = var.item.description
    default_vsys = "vsys1"
    location     = { panorama = {} }
    templates    = [module.templates.names["template"]]
    devices      = [for serial in var.item.serials : { name = serial }]
  } }
}

module "variables" {
  source = "../../modules/panos/panorama/template_variable"
  items = {
    wan_ip = {
      name        = "$wan_ip"
      description = "WAN interface IPv4 address and prefix length"
      location    = { template = { name = module.templates.names["template"] } }
      type        = { ip_netmask = var.item.var.wan_ip }
    }
    lan_ip = {
      name        = "$lan_ip"
      description = "LAN subinterface IPv4 address and prefix length"
      location    = { template = { name = module.templates.names["template"] } }
      type        = { ip_netmask = var.item.var.lan_ip }
    }
    mgmt_ip = {
      name        = "$mgmt_ip"
      description = "Management subinterface IPv4 address and prefix length"
      location    = { template = { name = module.templates.names["template"] } }
      type        = { ip_netmask = var.item.var.mgmt_ip }
    }
    default_gateway = {
      name        = "$default_gateway"
      description = "WAN next hop for the IPv4 default route"
      location    = { template = { name = module.templates.names["template"] } }
      type        = { ip_netmask = var.item.var.default_gateway }
    }
  }
}

module "interfaces" {
  source = "../../modules/panos/network/ethernet"
  items = {
    wan = {
      name     = var.item.var.wan_interface
      comment  = "WAN interface"
      location = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      layer3   = { ips = [{ name = module.variables.names["wan_ip"] }] }
    }
    lan = {
      name     = var.item.var.lan_interface
      comment  = "LAN interface"
      location = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      layer3   = {}
    }
  }
}

module "subinterfaces" {
  source = "../../modules/panos/network/ethernet_layer3_subinterface"
  items = {
    mgmt = {
      name     = "${module.interfaces.names["lan"]}.${var.item.var.mgmt_subinterface_tag}"
      parent   = module.interfaces.names["lan"]
      location = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      tag      = var.item.var.mgmt_subinterface_tag
      comment  = "Management subinterface"
      ip       = [{ name = module.variables.names["mgmt_ip"] }]
    }
    lan = {
      name     = "${module.interfaces.names["lan"]}.${var.item.var.lan_subinterface_tag}"
      parent   = module.interfaces.names["lan"]
      location = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      tag      = var.item.var.lan_subinterface_tag
      comment  = "LAN subinterface"
      ip       = [{ name = module.variables.names["lan_ip"] }]
    }
  }
}

# WAN and LAN profiles are supplied explicitly by the root configuration.
module "zone_protection_profiles" {
  source = "../../modules/panos/network/zone_protection_profile"
  items = {
    wan = merge(var.item.zone_protection_profiles.wan, {
      location = { template = { name = module.templates.names["template"] } }
    })
    lan = merge(var.item.zone_protection_profiles.lan, {
      location = { template = { name = module.templates.names["template"] } }
    })
  }
}

module "zones" {
  source = "../../modules/panos/network/zone"
  items = {
    wan = {
      name     = var.item.var.wan_zone
      location = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      network = {
        layer3                  = [module.interfaces.names["wan"]]
        zone_protection_profile = module.zone_protection_profiles.names["wan"]
      }
    }
    mgmt = {
      name     = var.item.var.mgmt_zone
      location = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      network  = { layer3 = [module.subinterfaces.names["mgmt"]] }
    }
    lan = {
      name     = var.item.var.lan_zone
      location = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      network = {
        layer3                  = [module.subinterfaces.names["lan"]]
        zone_protection_profile = module.zone_protection_profiles.names["lan"]
      }
    }
  }
}


module "routers" {
  source = "../../modules/panos/network/virtual_router"
  items = {
    mgmt = {
      name       = var.item.var.mgmt_virtual_router
      location   = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      interfaces = [module.subinterfaces.names["mgmt"]]
    }
    # Existing routers must be imported before Terraform manages membership.
    # Changing the name of a router already in state is not an adoption.
    data = {
      name       = var.item.var.data_virtual_router
      location   = { template = { name = module.templates.names["template"], vsys = "vsys1" } }
      interfaces = [module.interfaces.names["wan"], module.subinterfaces.names["lan"]]
    }
  }
}

module "routes" {
  source = "../../modules/panos/network/static_route_ipv4"
  items = {
    default = {
      name           = "default"
      location       = { template = { name = module.templates.names["template"] } }
      virtual_router = module.routers.names["data"]
      destination    = "0.0.0.0/0"
      interface      = module.interfaces.names["wan"]
      metric         = 10
      nexthop        = { ip_address = module.variables.names["default_gateway"] }
      route_table    = { unicast = {} }
    }
  }
}
