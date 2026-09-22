output "names" {
  description = "Logical input key to resource name."
  value = {
    for key, resource in panos_address_group.this :
    key => resource.name
  }
}
