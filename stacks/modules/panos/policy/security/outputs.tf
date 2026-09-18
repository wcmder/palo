# PAN-OS v2 has no computed .id. Return the documented base64 JSON
# import identifier, derived from provider-normalized state.
output "name_id" {
  description = "Policy logical key to PAN-OS import identifier; not a device UUID."
  value = {
    for key, resource in panos_security_policy.this : key => base64encode(jsonencode({
      names = [for rule in resource.rules : rule.name]
      location = { for scope, config in resource.location : scope => {
        for attribute, value in config : attribute => value if value != null
      } if config != null }
    }))
  }
}
output "names" {
  description = "Stable input key to ordered rule names, for references between modules."
  value       = { for key, resource in panos_security_policy.this : key => [for rule in resource.rules : rule.name] }
}
