resource "panos_tunnel_interface" "this" {
  for_each                     = var.items
  bonjour                      = each.value.bonjour
  comment                      = each.value.comment
  df_ignore                    = each.value.df_ignore
  interface_management_profile = each.value.interface_management_profile
  ip                           = each.value.ip
  ipv6                         = each.value.ipv6
  link_tag                     = each.value.link_tag
  location                     = each.value.location
  mtu                          = each.value.mtu
  name                         = each.value.name
  netflow_profile              = each.value.netflow_profile
}
