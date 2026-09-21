# PAN-OS v2 has no computed .id. Return the documented base64 JSON
# import identifier, derived from provider-normalized state.
output "name_id" {
  description = "Resource name to PAN-OS import identifier; not a device UUID."
  value = {
    for key, p in panos_ethernet_layer3_subinterface.this :
    p.name => base64encode(jsonencode({
      name   = p.name
      parent = p.parent
      location = { for scope, config in p.location : scope => {
        for attribute, value in config : attribute => value if value != null
      } if config != null }
    }))
  }
}
output "names" {
  description = "Logical role to subinterface name."
  value = {
    for key, p in panos_ethernet_layer3_subinterface.this : key => p.name
  }
}

output "assignments" {
  description = "Parent, VLAN tag and IP variables by role."
  value = {
    for key, p in panos_ethernet_layer3_subinterface.this : key => {
      parent = p.parent
      tag    = p.tag
      ip     = p.ip
    }
  }
}

output "management_profiles" {
  description = "Attached interface management profile by role."
  value = {
    for key, p in panos_ethernet_layer3_subinterface.this :
    key => p.interface_management_profile
  }
}
