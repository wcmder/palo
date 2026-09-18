resource "panos_nat_policy" "this" {
  for_each = var.items
  location = each.value.location
  rules    = each.value.rules
}
