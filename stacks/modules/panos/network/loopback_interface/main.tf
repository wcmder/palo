resource "panos_loopback_interface" "this" {
  for_each                     = var.items
  adjust_tcp_mss               = each.value.adjust_tcp_mss
  comment                      = each.value.comment
  interface_management_profile = each.value.interface_management_profile
  ip                           = each.value.ip
  ipv6                         = each.value.ipv6
  location                     = each.value.location
  mtu                          = each.value.mtu
  name                         = each.value.name
  netflow_profile              = each.value.netflow_profile
}
