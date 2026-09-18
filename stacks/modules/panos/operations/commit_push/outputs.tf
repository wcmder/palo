# Actions have invocation addresses, not remote resource IDs or import IDs.
output "name_id" {
  description = "Target-name to module-relative action address, grouped by operation. Prefix with the module address when invoking."
  value = {
    commit_and_push = { for key, item in local.push_items : key => "action.panos_commit.commit_and_push[${jsonencode(key)}]" }
    commit          = { for key, item in var.items : key => "action.panos_commit.this[${jsonencode(key)}]" }
    push            = { for key, item in local.push_items : key => "action.panos_push_to_devices.this[${jsonencode(key)}]" }
  }
}

output "push_targets" {
  description = "Explicit device-group and serial selections for eligible push actions."
  value = { for key, item in local.push_items : key => {
    device_group = item.device_group
    serials      = item.serials
  } }
}
