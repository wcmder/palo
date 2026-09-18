output "name_id" {
  description = "Import identifiers grouped by resource type and site to avoid cross-type name collisions."
  value = {
    device_groups   = module.device_groups.name_id
    templates       = module.templates.name_id
    template_stacks = module.template_stacks.name_id
    addresses       = { for site, instance in module.addresses : site => instance.name_id }
  }
}
output "names" {
  value = {
    device_groups   = module.device_groups.names
    templates       = module.templates.names
    template_stacks = module.template_stacks.names
  }
}
