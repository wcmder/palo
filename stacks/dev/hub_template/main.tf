# Reserved for future hub networking that requires a different resource structure.
# This scaffold creates no resources and is not called by the environment root.
# For different values with the same WAN/LAN layout, use another templates entry
# with the existing spoke_template module instead.
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

# Profiles are optional for other template callers; dev tfvars enables WAN and LAN.
module "zone_protection_profiles" {
  for_each = var.items
  source   = "../../modules/panos/network/zone_protection_profile"
  items = { for key, profile in try(each.value.zone_protection_profiles, {}) : key => merge(profile, {
    location = { template = { name = module.templates.names[each.key] } }
  }) }
}

module "zones" {
  for_each = var.items
  source   = "../../modules/panos/network/zone"
  items = {
    wan = {
      name     = each.value.var.wan_zone
      location = { template = { name = module.templates.names[each.key], vsys = "vsys1" } }
      network = {
        layer3                  = [module.interfaces[each.key].names["wan"]]
        zone_protection_profile = try(module.zone_protection_profiles[each.key].names["wan"], null)
      }
    }
    lan = {
      name     = each.value.var.lan_zone
      location = { template = { name = module.templates.names[each.key], vsys = "vsys1" } }
      network = {
        layer3                  = [module.interfaces[each.key].names["lan"]]
        zone_protection_profile = try(module.zone_protection_profiles[each.key].names["lan"], null)
      }
    }
  }
}


module "routers" {
  for_each = var.items
  source   = "../../modules/panos/network/virtual_router"
  items = {
    # Existing routers must be imported before Terraform manages membership.
    # Changing the name of a router already in state is not an adoption.
    data = {
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
      virtual_router = module.routers[each.key].names["data"]
      destination    = "0.0.0.0/0"
      interface      = module.interfaces[each.key].names["wan"]
      metric         = 10
      nexthop        = { ip_address = module.variables[each.key].names["default_gateway"] }
      route_table    = { unicast = {} }
    }
  }
}
