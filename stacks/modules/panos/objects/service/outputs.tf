output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_service.this : key => resource.name }
}

output "locations" {
  value = {
    for key, resource in panos_service.this : key => resource.location
  }
}
