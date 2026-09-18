# Shared device-group commits can include changes for other spokes in the group.
# Combined push targets contain only serials shared by the selected group and stack.
# Explicit actions live here and in the reusable module; no automatic triggers.
#
# Commit and push are separate commands; you can stop after commit and push later.
# Before any push-only action or push-all, successfully commit the changes you
# intend to deploy to Panorama. Push sends committed configuration only; it does
# not commit pending edits. To commit all configured lab containers first:
# palo lab apply -invoke='action.panos_commit.all'
# Wait for success before pushing. If those changes were already committed through
# Terraform or the Panorama GUI, another commit is unnecessary. The combined
# commit_and_push action performs its own commit before pushing its target.
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
# Push every configured target after a successful commit:
# push-all is a Python CLI command implemented in src/palo_cli/push_all.py,
# not a Terraform action or a direct Python call to the Panorama API.
# It invokes module.deployment.action.panos_push_to_devices.this for each
# target in local.deployment_items; the PAN-OS provider performs the API calls.
# palo lab apply -invoke='action.panos_commit.all'
# palo lab push-all --dry-run
# palo lab push-all
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
  # Separate pushes use their own membership, without requiring a group/stack pair.
  # Exclude empty assignments so an empty device list cannot broaden a push.
  template_push_items = { for key, item in var.templates : key => item if length(item.serials) > 0 }
  policy_push_items   = { for name, group in var.device_groups : name => group if length(try(group.serials, [])) > 0 }

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

# TEMPLATE ONLY: commit to Panorama first (action.panos_commit.all), then push.
# Uses the var.templates key; no device group is required.
# palo lab plan -invoke='action.panos_push_to_devices.templates["spoke"]'
# palo lab apply -invoke='action.panos_push_to_devices.templates["spoke"]'
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

# POLICY ONLY: commit to Panorama first (action.panos_commit.all), then push.
# Uses the var.device_groups key; no template assignment is required.
# Push a child group to deploy its policies and inherited parent policies.
# Groups without directly assigned serials have no push action.
# palo lab plan -invoke='action.panos_push_to_devices.policies["spoke"]'
# palo lab apply -invoke='action.panos_push_to_devices.policies["spoke"]'
action "panos_push_to_devices" "policies" {
  for_each = local.policy_push_items
  config {
    description      = "Push policies for device group ${each.key}"
    type             = "device_group"
    name             = each.key
    devices          = each.value.serials
    include_template = false
  }
}

# Commit all policy/template containers, including groups without assigned devices.
# This action is declared in the environment root, so its address has no module prefix.
# Preview:
# palo lab plan -invoke='action.panos_commit.all'
# Execute:
# palo lab apply -invoke='action.panos_commit.all'
# Per-target actions declared inside module.deployment require that module prefix,
# for example: module.deployment.action.panos_commit.this["spoke/spoke"].
# After commit-all succeeds, push every configured target with:
# palo lab push-all
action "panos_commit" "all" {
  config {
    description     = "Commit lab policy and templates"
    device_groups   = keys(var.device_groups)
    templates       = [for item in values(var.templates) : item.name]
    template_stacks = [for item in values(var.templates) : item.stack]
    force           = false
  }
}
