# Each map entry is passed to the typed resource module, with its template scope.
module "templates" {
  source = "../../../modules/panos/panorama/template"
  items = { for key, item in var.items : key => {
    name         = item.name
    description  = try(item.description, "Terraform-managed network template")
    default_vsys = try(item.vsys, "vsys1")
    location     = { panorama = {} }
  } }
}

module "template_stacks" {
  source = "../../../modules/panos/panorama/template_stack"
  items = { for key, item in var.items : key => {
    name         = item.stack
    description  = try(item.description, "Terraform-managed network template")
    default_vsys = try(item.vsys, "vsys1")
    location     = { panorama = {} }
    templates    = [module.templates.names[key]]
    devices      = [for serial in try(item.serials, []) : { name = serial }]
  } }
}

module "variables" {
  for_each = var.items
  source   = "../../../modules/panos/panorama/template_variable"
  items = { for key, config in try(each.value.var, {}) : key => merge(config, {
    name     = format("$%s", key)
    location = { template = { name = module.templates.names[each.key] } }
  }) }
}

module "interfaces" {
  for_each = var.items
  source   = "../../../modules/panos/network/ethernet"
  items = { for key, config in try(each.value.interfaces, {}) : key => merge(config, {
    location = { template = { name = module.templates.names[each.key], vsys = try(each.value.vsys, "vsys1") } }
  }) }
  depends_on = [module.variables]
}

module "zones" {
  for_each = var.items
  source   = "../../../modules/panos/network/zone"
  items = { for key, config in try(each.value.zones, {}) : key => merge({ name = key }, config, {
    location = { template = { name = module.templates.names[each.key], vsys = try(each.value.vsys, "vsys1") } }
  }) }
  depends_on = [module.interfaces]
}

module "routers" {
  for_each = var.items
  source   = "../../../modules/panos/network/virtual_router"
  items = { for key, config in try(each.value.routers, {}) : key => merge({ name = key }, config, {
    location = { template = { name = module.templates.names[each.key], vsys = try(each.value.vsys, "vsys1") } }
  }) }
  depends_on = [module.interfaces]
}

module "routes" {
  for_each = var.items
  source   = "../../../modules/panos/network/static_route_ipv4"
  items = { for key, config in try(each.value.routes, {}) : key => merge({ name = key }, config, {
    location = { template = { name = module.templates.names[each.key] } }
  }) }
  depends_on = [module.routers, module.variables]
}
