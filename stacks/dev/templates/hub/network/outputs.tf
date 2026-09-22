output "names" {
  value = {
    interface_management_profiles = module.interface_management_profiles.names
    subinterfaces                 = module.subinterfaces.names
    template                      = module.templates.names.template
    interfaces                    = module.interfaces.names
    tunnel_interfaces             = module.tunnel_interfaces.names
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

output "gre_router_interfaces" {
  value = module.routers.interfaces.mgmt
}

output "gre_zone_interfaces" {
  value = module.zones.interfaces.mgmt
}

output "gre_endpoints" {
  value = module.gre_tunnels.endpoints
}

output "network_locations" {
  value = {
    interfaces = module.interfaces.locations
    routers    = module.routers.locations
    zones      = module.zones.locations
  }
}
