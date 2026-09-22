output "names" {
  description = "Logical input key to resource name."
  value = {
    for key, resource in panos_address.this :
    key => resource.name
  }
}
