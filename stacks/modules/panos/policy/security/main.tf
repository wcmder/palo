resource "panos_security_policy" "this" {
  for_each = var.items
  location = each.value.location
  rules    = each.value.rules
}
