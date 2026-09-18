module "templates" {
  source = "../../modules/panos/panorama/template"
  items = { for key, item in var.items : key => {
    name         = item.name
    description  = item.description
    default_vsys = "vsys1"
    location     = { panorama = {} }
  } }
}

module "template_stacks" {
  source = "../../modules/panos/panorama/template_stack"
  items = { for key, item in var.items : key => {
    name         = item.stack
    description  = item.description
    default_vsys = "vsys1"
    location     = { panorama = {} }
    templates    = [module.templates.names[key]]
    devices      = [for serial in item.serials : { name = serial }]
  } }
}

module "variables" {
  for_each = var.items
  source   = "../../modules/panos/panorama/template_variable"
  items = {
    wan_ip = {
      name        = "$wan_ip"
      description = "WAN interface IPv4 address and prefix length"
      location    = { template = { name = module.templates.names[each.key] } }
      type        = { ip_netmask = each.value.var.wan_ip == "None" ? "None" : "${each.value.var.wan_ip}/${each.value.var.wan_prefix_length}" }
    }
    lan_ip = {
      name        = "$lan_ip"
      description = "LAN interface IPv4 address and prefix length"
      location    = { template = { name = module.templates.names[each.key] } }
      type        = { ip_netmask = each.value.var.lan_ip == "None" ? "None" : "${each.value.var.lan_ip}/${each.value.var.lan_prefix_length}" }
    }
    default_gateway = {
      name        = "$default_gateway"
      description = "WAN next hop for the IPv4 default route"
      location    = { template = { name = module.templates.names[each.key] } }
      type        = { ip_netmask = each.value.var.default_gateway }
    }
  }
}

module "interfaces" {
  for_each = var.items
  source   = "../../modules/panos/network/ethernet"
  items = {
    wan = {
      name     = each.value.var.wan_interface
      comment  = "WAN interface"
      location = { template = { name = module.templates.names[each.key], vsys = "vsys1" } }
      layer3   = { ips = [{ name = module.variables[each.key].names["wan_ip"] }] }
    }
    lan = {
      name     = each.value.var.lan_interface
      comment  = "LAN interface"
      location = { template = { name = module.templates.names[each.key], vsys = "vsys1" } }
      layer3   = { ips = [{ name = module.variables[each.key].names["lan_ip"] }] }
    }
  }
}

module "zones" {
  for_each = var.items
  source   = "../../modules/panos/network/zone"
  items = {
    wan = {
      name     = each.value.var.wan_zone
      location = { template = { name = module.templates.names[each.key], vsys = "vsys1" } }
      network  = { layer3 = [module.interfaces[each.key].names["wan"]] }
    }
    lan = {
      name     = each.value.var.lan_zone
      location = { template = { name = module.templates.names[each.key], vsys = "vsys1" } }
      network  = { layer3 = [module.interfaces[each.key].names["lan"]] }
    }
  }
}

module "routers" {
  for_each = var.items
  source   = "../../modules/panos/network/virtual_router"
  items = {
    # Keep the existing resource key; the actual router name is an input.
    spoke = {
      name       = each.value.var.virtual_router
      location   = { template = { name = module.templates.names[each.key], vsys = "vsys1" } }
      interfaces = [module.interfaces[each.key].names["wan"], module.interfaces[each.key].names["lan"]]
    }
  }
}

module "routes" {
  for_each = var.items
  source   = "../../modules/panos/network/static_route_ipv4"
  items = {
    default = {
      name           = "default"
      location       = { template = { name = module.templates.names[each.key] } }
      virtual_router = module.routers[each.key].names["spoke"]
      destination    = "0.0.0.0/0"
      interface      = module.interfaces[each.key].names["wan"]
      metric         = 10
      nexthop        = { ip_address = module.variables[each.key].names["default_gateway"] }
      route_table    = { unicast = {} }
    }
  }
}
