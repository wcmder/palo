output "names" {
  description = "Logical input key to ordered rule names."
  value = {
    for key, resource in panos_nat_policy.this :
    key => [for rule in resource.rules : rule.name]
  }
}

output "locations" {
  value = {
    for key, resource in panos_nat_policy.this : key => resource.location
  }
}
