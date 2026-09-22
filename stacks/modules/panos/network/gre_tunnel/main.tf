resource "panos_gre_tunnel" "this" {
  for_each         = var.items
  copy_tos         = each.value.copy_tos
  disabled         = each.value.disabled
  erspan           = each.value.erspan
  keep_alive       = each.value.keep_alive
  local_address    = each.value.local_address
  location         = each.value.location
  name             = each.value.name
  peer_address     = each.value.peer_address
  ttl              = each.value.ttl
  tunnel_interface = each.value.tunnel_interface
}
