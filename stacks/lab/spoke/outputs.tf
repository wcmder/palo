output "name_id" {
  description = "Resource-name/import-ID maps grouped by resource type and spoke."
  value       = merge(module.template.name_id, { device_groups = module.policy.name_id })
}

output "names" {
  value = merge(module.template.names, { device_groups = module.policy.names })
}

output "device_group_memberships" {
  description = "Shared device group name to combined serials across its spokes."
  value       = module.policy.device_group_memberships
}
