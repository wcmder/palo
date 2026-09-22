output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_zone_protection_profile.this : key => resource.name }
}

output "locations" {
  value = {
    for key, resource in panos_zone_protection_profile.this : key => resource.location
  }
}
