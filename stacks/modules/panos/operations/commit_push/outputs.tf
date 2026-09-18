# Actions have invocation addresses, not remote resource IDs or import IDs.
output "name_id" {
  description = "Target-name to module-relative action address, grouped by operation. Prefix with the module address when invoking."
  value = {
    commit_all      = { all = "action.panos_commit.all" }
    templates       = { for key, item in local.template_push_items : key => "action.panos_push_to_devices.templates[${jsonencode(key)}]" }
    policies        = { for key, item in local.policy_push_items : key => "action.panos_push_to_devices.policies[${jsonencode(key)}]" }
    commit_and_push = { for key, item in local.deployment_items : key => "action.panos_commit.commit_and_push[${jsonencode(key)}]" }
    commit          = { for key, item in local.deployment_items : key => "action.panos_commit.this[${jsonencode(key)}]" }
    push            = { for key, item in local.deployment_items : key => "action.panos_push_to_devices.this[${jsonencode(key)}]" }
  }
}

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
