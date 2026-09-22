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
