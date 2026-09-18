resource "panos_device_group" "this" {
  for_each           = var.items
  authorization_code = each.value.authorization_code
  description        = each.value.description
  devices            = each.value.devices
  location           = each.value.location
  name               = each.value.name
  templates          = each.value.templates
}
