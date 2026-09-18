resource "panos_template_variable" "this" {
  for_each    = var.items
  description = each.value.description
  location    = each.value.location
  name        = each.value.name
  type        = each.value.type
}
