output "names" {
  description = "Logical input key to resource name."
  value = {
    for key, resource in panos_virtual_router_static_route_ipv4.this :
    key => resource.name
  }
}

output "locations" {
  value = {
    for key, resource in panos_virtual_router_static_route_ipv4.this : key => resource.location
  }
}
