output "templates" {
  description = "Ordered template membership by logical stack key."
  value = {
    for key, stack in panos_template_stack.this : key => stack.templates
  }
}

output "names" {
  description = "Logical input key to resource name."
  value = {
    for key, resource in panos_template_stack.this :
    key => resource.name
  }
}
