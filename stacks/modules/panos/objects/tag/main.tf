resource "panos_administrative_tag" "this" {
  for_each         = var.items
  color            = each.value.color
  comments         = each.value.comments
  disable_override = each.value.disable_override
  location         = each.value.location
  name             = each.value.name
}
