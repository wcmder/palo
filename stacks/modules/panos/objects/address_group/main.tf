resource "panos_address_group" "this" {
  for_each         = var.items
  description      = each.value.description
  disable_override = each.value.disable_override
  dynamic          = each.value.dynamic
  location         = each.value.location
  name             = each.value.name
  static           = each.value.static
  tag              = each.value.tag
}
