# Shared device-group commits can include changes for other spokes in the group.
# Push targets remain restricted to the selected spoke's serials.
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
# palo lab plan -invoke='module.deployment.action.panos_commit.this["spoke01"]'
# Execute:
# palo lab apply -invoke='module.deployment.action.panos_commit.this["spoke01"]'
#
# Step 3: PUSH ONLY to assigned firewalls, after the Panorama commit succeeds.
# This pushes committed configuration; it does not commit new Panorama edits.
# Preview:
# palo lab plan -invoke='module.deployment.action.panos_push_to_devices.this["spoke01"]'
# Execute:
# palo lab apply -invoke='module.deployment.action.panos_push_to_devices.this["spoke01"]'
#
#
# Alternative to steps 2 and 3: COMMIT AND PUSH in a single action, after step 1.
# Preview:
# palo lab plan -invoke='module.deployment.action.panos_commit.commit_and_push["spoke01"]'
# Execute:
# palo lab apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke01"]'
#
# Replace spoke01 with the key in var.spokes.
# Push-only and combined actions both require non-empty serials.
module "deployment" {
  source = "../../stacks/modules/panos/operations/commit_push"
  items = { for key, item in var.spokes : key => {
    device_group   = item.policy.device_group
    template       = item.template.name
    template_stack = item.template.stack
    serials        = try(item.serials, [])
  } }
}
