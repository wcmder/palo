output "templates" {
  value = module.template_stacks.templates["template"]
}

output "serials" {
  value = var.item.serials
}

output "names" {
  value = module.template_stacks.names
}
