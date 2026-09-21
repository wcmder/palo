resource "panos_ethernet_layer3_subinterface" "this" {
  for_each = var.items
  name     = each.value.name
  parent   = each.value.parent
  location = each.value.location
  tag      = each.value.tag
  comment  = each.value.comment
  ip       = each.value.ip
}
