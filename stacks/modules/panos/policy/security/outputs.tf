output "names" {
  description = "Logical input key to ordered rule names."
  value = {
    for key, resource in panos_security_policy.this :
    key => [for rule in resource.rules : rule.name]
  }
}
