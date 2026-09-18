resource "panos_device_group_parent" "this" {
  for_each     = var.items
  device_group = each.value.device_group
  parent       = each.value.parent
  location     = each.value.location
}
