output "names" {
  value = {
    interface_management_profiles = module.interface_management_profiles.names
    subinterfaces                 = module.subinterfaces.names
    templates                     = module.templates.names
    interfaces                    = module.interfaces.names
    variables                     = module.variables.names
  }
}

output "variable_values" {
  description = "Configured template variable defaults keyed by variable name."
  value       = module.variables.values
}

output "zone_protection_locations" {
  value = module.zone_protection_profiles.locations
}
