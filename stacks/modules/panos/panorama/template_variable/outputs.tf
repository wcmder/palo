output "names" {
  description = "Stable input key to resource name, for references between modules."
  value       = { for key, resource in panos_template_variable.this : key => resource.name }
}

output "values" {
  description = "Variable name to configured value (all variable types are strings)."
  value       = { for key, resource in panos_template_variable.this : resource.name => one([for value in resource.type : value if value != null]) }
}
