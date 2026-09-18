# One owner per device-group/shared default-security rulebase.
resource "panos_default_security_policy" "this" {
  for_each = var.items
  location = each.value.location
  rules    = each.value.rules
}
