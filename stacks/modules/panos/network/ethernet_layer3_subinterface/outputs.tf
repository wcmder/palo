# PAN-OS v2 has no computed .id. Return the documented base64 JSON
# import identifier, derived from provider-normalized state.
output "name_id" {
  description = "Resource name to PAN-OS import identifier; not a device UUID."
  value = {
    for key, resource in panos_ethernet_layer3_subinterface.this : resource.name => base64encode(jsonencode({
      name   = resource.name
      parent = resource.parent
      location = { for scope, config in resource.location : scope => {
        for attribute, value in config : attribute => value if value != null
      } if config != null }
    }))
  }
}
output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_ethernet_layer3_subinterface.this : key => resource.name }
}

output "assignments" {
  description = "Configured parent, VLAN tag and IP variables keyed by input key."
  value       = { for key, resource in panos_ethernet_layer3_subinterface.this : key => { parent = resource.parent, tag = resource.tag, ip = resource.ip } }
}
