output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_template.this : key => resource.name }
}
