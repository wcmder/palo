output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_device_group.this : key => resource.name }
}
