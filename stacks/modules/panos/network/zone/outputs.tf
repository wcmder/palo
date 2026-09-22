output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_zone.this : key => resource.name }
}

output "zone_protection_profiles" {
  description = "Zone input key to its attached zone protection profile."
  value       = { for key, resource in panos_zone.this : key => try(resource.network.zone_protection_profile, null) }
}

output "interfaces" {
  description = "Configured Layer 3 interface membership keyed by input key."
  value       = { for key, resource in panos_zone.this : key => resource.network.layer3 }
}
