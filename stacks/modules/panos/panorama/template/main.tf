resource "panos_template" "this" {
  for_each     = var.items
  default_vsys = each.value.default_vsys
  description  = each.value.description
  location     = each.value.location
  name         = each.value.name
}
