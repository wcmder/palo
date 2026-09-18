resource "panos_service" "this" {
  for_each         = var.items
  description      = each.value.description
  disable_override = each.value.disable_override
  location         = each.value.location
  name             = each.value.name
  protocol         = each.value.protocol
  tags             = each.value.tags
}
