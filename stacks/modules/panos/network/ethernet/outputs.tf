output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_ethernet_interface.this : key => resource.name }
}

output "management_profiles" {
  description = "Attached Layer 3 management profile by role."
  value = {
    for key, p in panos_ethernet_interface.this :
    key => try(p.layer3.interface_management_profile, null)
  }
}

output "locations" {
  value = {
    for key, resource in panos_ethernet_interface.this :
    key => resource.location
  }
}
