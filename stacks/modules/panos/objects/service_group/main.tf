resource "panos_service_group" "this" {
  for_each         = var.items
  disable_override = each.value.disable_override
  location         = each.value.location
  members          = each.value.members
  name             = each.value.name
  tags             = each.value.tags
}
