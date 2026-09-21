output "name_id" {
  description = "Resource-name/import-ID maps grouped by resource type."
  value = {
    interface_management_profiles = (
      module.interface_management_profiles.name_id
    )
    subinterfaces            = module.subinterfaces.name_id
    templates                = module.templates.name_id
    template_stacks          = module.template_stacks.name_id
    variables                = module.variables.name_id
    interfaces               = module.interfaces.name_id
    zone_protection_profiles = module.zone_protection_profiles.name_id
    zones                    = module.zones.name_id
    virtual_routers          = module.routers.name_id
    routes                   = module.routes.name_id
  }
}

output "names" {
  value = {
    interface_management_profiles = module.interface_management_profiles.names
    subinterfaces                 = module.subinterfaces.names
    templates                     = module.templates.names
    template_stacks               = module.template_stacks.names
    interfaces                    = module.interfaces.names
    variables                     = module.variables.names
  }
}


output "variable_values" {
  description = "Configured template variable defaults keyed by variable name."
  value       = module.variables.values
}
