module "device_groups" {
  source = "../../modules/panos/panorama/device_group"
  items = { for key, site in var.sites : key => {
    name        = site.device_group
    description = site.description
    location    = { panorama = {} }
    devices     = [for serial in site.serials : { name = serial }]
  } }
}
module "templates" {
  source = "../../modules/panos/panorama/template"
  items = { for key, site in var.sites : key => {
    name        = site.template
    description = site.description
    location    = { panorama = {} }
  } }
}
module "template_stacks" {
  source = "../../modules/panos/panorama/template_stack"
  items = { for key, site in var.sites : key => {
    name        = site.template_stack
    description = site.description
    location    = { panorama = {} }
    templates   = [module.templates.names[key]]
    devices     = [for serial in site.serials : { name = serial }]
  } }
}
module "addresses" {
  for_each = var.sites
  source   = "../../modules/panos/objects/address"
  items = { for name, cidr in each.value.addresses : name => {
    name       = name
    ip_netmask = cidr
    location   = { device_group = { name = module.device_groups.names[each.key] } }
  } }
}
