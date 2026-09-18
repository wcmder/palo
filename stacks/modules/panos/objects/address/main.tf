resource "panos_address" "this" {
  for_each         = var.items
  description      = each.value.description
  disable_override = each.value.disable_override
  fqdn             = each.value.fqdn
  ip_netmask       = each.value.ip_netmask
  ip_range         = each.value.ip_range
  ip_wildcard      = each.value.ip_wildcard
  location         = each.value.location
  name             = each.value.name
  tags             = each.value.tags
}
