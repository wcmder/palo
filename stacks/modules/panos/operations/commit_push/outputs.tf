output "push_targets" {
  description = "Explicit device-group and serial selections for eligible push actions."
  value = { for key, item in local.deployment_items : key => {
    device_group = item.device_group
    serials      = item.serials
  } }
}

output "deployment_items" {
  description = "Combined deployment targets, including commit containers and shared serials."
  value       = local.deployment_items
}

output "template_push_items" {
  description = "Template stack push targets with non-empty serial assignments."
  value       = local.template_push_items
}

output "policy_push_items" {
  description = "Policy push targets with directly assigned serials."
  value       = local.policy_push_items
}
