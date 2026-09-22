output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_virtual_router.this : key => resource.name }
}

output "interfaces" {
  description = "Configured Layer 3 interface membership keyed by input key."
  value       = { for key, resource in panos_virtual_router.this : key => resource.interfaces }
}

output "locations" {
  value = {
    for key, resource in panos_virtual_router.this :
    key => resource.location
  }
}
