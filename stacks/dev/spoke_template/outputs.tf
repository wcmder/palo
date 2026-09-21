output "name_id" {
  description = "Resource-name/import-ID maps grouped by resource type and item."
  value = {
    templates                = module.templates.name_id
    template_stacks          = module.template_stacks.name_id
    variables                = { for key, instance in module.variables : key => instance.name_id }
    interfaces               = { for key, instance in module.interfaces : key => instance.name_id }
    zone_protection_profiles = { for key, instance in module.zone_protection_profiles : key => instance.name_id }
    zones                    = { for key, instance in module.zones : key => instance.name_id }
    virtual_routers          = { for key, instance in module.routers : key => instance.name_id }
    routes                   = { for key, instance in module.routes : key => instance.name_id }
  }
}

output "names" {
  value = {
    templates       = module.templates.names
    template_stacks = module.template_stacks.names
    interfaces      = { for key, instance in module.interfaces : key => instance.names }
    variables       = { for key, instance in module.variables : key => instance.names }
  }
}


output "variable_values" {
  description = "Configured template variable defaults keyed by item and variable name."
  value       = { for key, instance in module.variables : key => instance.values }
}
