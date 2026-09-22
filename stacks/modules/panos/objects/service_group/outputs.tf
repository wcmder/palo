output "names" {
  description = "Logical input key to resource name."
  value = {
    for key, resource in panos_service_group.this :
    key => resource.name
  }
}
