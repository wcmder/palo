resource "panos_virtual_router_static_route_ipv4" "this" {
  for_each       = var.items
  admin_dist     = each.value.admin_dist
  bfd            = each.value.bfd
  destination    = each.value.destination
  interface      = each.value.interface
  location       = each.value.location
  metric         = each.value.metric
  name           = each.value.name
  nexthop        = each.value.nexthop
  path_monitor   = each.value.path_monitor
  route_table    = each.value.route_table
  virtual_router = each.value.virtual_router
}
