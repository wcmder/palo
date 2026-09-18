resource "panos_template_stack" "this" {
  for_each          = var.items
  default_vsys      = each.value.default_vsys
  description       = each.value.description
  devices           = each.value.devices
  location          = each.value.location
  name              = each.value.name
  templates         = each.value.templates
  user_group_source = each.value.user_group_source
}
