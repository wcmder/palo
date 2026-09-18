output "name_id" {
  description = "Device-group name to import identity."
  value       = module.device_groups.name_id
}

output "names" {
  value = module.device_groups.names
}

output "device_group_memberships" {
  value = module.device_groups.devices
}
