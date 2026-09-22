output "names" {
  description = "Logical input key to resource name."
  value = {
    for key, resource in panos_administrative_tag.this :
    key => resource.name
  }
}
