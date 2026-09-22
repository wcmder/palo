locals {
  # Separate pushes use their own membership, without requiring a group/stack pair.
  # Exclude empty assignments so an empty device list cannot broaden a push.
  template_push_items = { for key, item in var.templates : key => item if length(item.serials) > 0 }
  policy_push_items   = { for name, group in var.device_groups : name => group if length(try(group.serials, [])) > 0 }

  # Each push targets only the intersection of a device group and template stack.
  deployment_items = merge({}, [for group_name, group in var.device_groups : {
    for template_key, template in var.templates : "${group_name}/${template_key}" => {
      device_group   = group.device_group
      device_groups  = compact([try(group.parent, null), group.device_group])
      templates      = template.templates
      template_stack = template.stack
      serials        = sort(tolist(setintersection(toset(try(group.serials, [])), toset(template.serials))))
    } if length(setintersection(toset(try(group.serials, [])), toset(template.serials))) > 0
  }]...)
}

action "panos_push_to_devices" "templates" {
  for_each = local.template_push_items
  config {
    description           = "Push template stack ${each.value.stack}"
    type                  = "template_stack"
    name                  = each.value.stack
    devices               = each.value.serials
    force_template_values = false
  }
}

action "panos_push_to_devices" "policies" {
  for_each = local.policy_push_items
  config {
    description      = "Push policies for device group ${each.key}"
    type             = "device_group"
    name             = each.value.device_group
    devices          = each.value.serials
    include_template = false
  }
}

# Full Panorama commit: no administrator or container filters.
# Includes all pending changes, including edits outside this Terraform environment.
action "panos_commit" "all" {
  config {
    description = "Full Panorama commit"
    force       = false
  }
}

# Explicit operations: normal plan/apply does not commit or push.
# Apply candidate changes first, invoke commit, wait for success, then invoke push.
# This is a partial commit limited to the selected target's containers.
action "panos_commit" "this" {
  for_each = local.deployment_items

  config {
    description     = "Commit target ${each.key}"
    device_groups   = distinct(concat(each.value.device_groups, [each.value.device_group]))
    templates       = each.value.templates
    template_stacks = [each.value.template_stack]
    force           = false
  }
}

action "panos_push_to_devices" "this" {
  # No push action exists for a spoke with no firewall assignments.
  for_each = local.deployment_items

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
  for_each = local.deployment_items

  config {
    description     = "Commit and push target ${each.key}"
    device_groups   = distinct(concat(each.value.device_groups, [each.value.device_group]))
    templates       = each.value.templates
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
