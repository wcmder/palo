output "names" {
  value = {
    template   = module.templates.names.template
    interfaces = module.tunnel_interfaces.names
    variables  = module.variables.names
  }
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
