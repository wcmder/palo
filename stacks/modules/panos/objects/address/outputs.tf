# PAN-OS v2 has no computed .id. Return the documented base64 JSON
# import identifier, derived from provider-normalized state.
output "name_id" {
  description = "Resource name to PAN-OS import identifier; not a device UUID."
  value = {
    for key, resource in panos_address.this : resource.name => base64encode(jsonencode({
      name = resource.name
      location = { for scope, config in resource.location : scope => {
        for attribute, value in config : attribute => value if value != null
      } if config != null }
    }))
  }
}
output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_address.this : key => resource.name }
}
