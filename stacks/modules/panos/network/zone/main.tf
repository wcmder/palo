resource "panos_zone" "this" {
  for_each                     = var.items
  device_acl                   = each.value.device_acl
  enable_device_identification = each.value.enable_device_identification
  enable_user_identification   = each.value.enable_user_identification
  location                     = each.value.location
  name                         = each.value.name
  network                      = each.value.network
  user_acl                     = each.value.user_acl
}
