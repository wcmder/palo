# Shared device-group commits can include changes for other spokes in the group.
# Push targets contain only serials shared by the selected group and stack.
# Explicit actions live in the reusable module; no automatic action triggers.
#
# Commit and push are separate commands; you can stop after commit and push later.
#
# Step 1: Apply candidate configuration (does not commit or push).
# palo lab plan
# palo lab apply
#
# Before committing, preview/apply device variables from device_overrides.json:
# palo lab overrides plan
# palo lab overrides apply
# These commands write candidate per-device overrides only; they do not commit/push.
# --device limits override writes, not the serials targeted by the actions below.
#
# Step 2: COMMIT ONLY to Panorama (does not push to firewalls).
# Preview:
# palo lab plan -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
# Execute:
# palo lab apply -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
#
# Step 3: PUSH ONLY to assigned firewalls, after the Panorama commit succeeds.
# This pushes committed configuration; it does not commit new Panorama edits.
# Preview:
# palo lab plan -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
# Execute:
# palo lab apply -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
#
#
# Alternative to steps 2 and 3: COMMIT AND PUSH in a single action, after step 1.
# Preview:
# palo lab plan -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
# Execute:
# palo lab apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
#
# Replace spoke/spoke with the device-group/template key in local.deployment_items.
# Push-only and combined actions both require non-empty serials.
locals {
  # Each push targets only the intersection of a device group and template stack.
  deployment_items = merge({}, [for group_name, group in var.device_groups : {
    for template_key, template in var.templates : "${group_name}/${template_key}" => {
      device_group   = group_name
      device_groups  = compact([try(group.parent, null), group_name])
      template       = template.name
      template_stack = template.stack
      serials        = sort(tolist(setintersection(toset(try(group.serials, [])), toset(template.serials))))
    } if length(setintersection(toset(try(group.serials, [])), toset(template.serials))) > 0
  }]...)
}

module "deployment" {
  source = "../../stacks/modules/panos/operations/commit_push"
  items  = local.deployment_items
}

# Commit all policy/template containers, including groups without assigned devices.
# palo lab apply -invoke='action.panos_commit.all'
action "panos_commit" "all" {
  config {
    description     = "Commit lab policy and templates"
    device_groups   = keys(var.device_groups)
    templates       = [for item in values(var.templates) : item.name]
    template_stacks = [for item in values(var.templates) : item.stack]
    force           = false
  }
}
