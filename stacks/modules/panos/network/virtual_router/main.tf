resource "panos_virtual_router" "this" {
  for_each                 = var.items
  administrative_distances = each.value.administrative_distances
  ecmp                     = each.value.ecmp
  interfaces               = each.value.interfaces
  location                 = each.value.location
  multicast                = each.value.multicast
  name                     = each.value.name
  protocol                 = each.value.protocol
}
