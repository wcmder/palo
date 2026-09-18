# Explicit operations: normal plan/apply does not commit or push.
# Apply candidate changes first, invoke commit, wait for success, then invoke push.
action "panos_commit" "this" {
  for_each = var.items

  config {
    description     = "Commit target ${each.key}"
    device_groups   = distinct(concat(each.value.device_groups, [each.value.device_group]))
    templates       = [each.value.template]
    template_stacks = [each.value.template_stack]
    force           = false
  }
}

locals {
  push_items = {
    for key, spoke in var.items : key => spoke
    if length(spoke.serials) > 0
  }
}

action "panos_push_to_devices" "this" {
  # No push action exists for a spoke with no firewall assignments.
  for_each = local.push_items

  config {
    description           = "Push target ${each.key}"
    type                  = "device_group"
    name                  = each.value.device_group
    devices               = each.value.serials
    include_template      = true
    force_template_values = false
  }
}

# Alternative to invoking commit and push separately, after candidate apply.
action "panos_commit" "commit_and_push" {
  for_each = local.push_items

  config {
    description     = "Commit and push target ${each.key}"
    device_groups   = distinct(concat(each.value.device_groups, [each.value.device_group]))
    templates       = [each.value.template]
    template_stacks = [each.value.template_stack]
    force           = false

    push_configuration = {
      type                  = "device_group"
      name                  = each.value.device_group
      devices               = each.value.serials
      include_template      = true
      force_template_values = false
    }
  }
}
