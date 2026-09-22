# Shared explicit actions; ordinary plan/apply does not commit or push.
module "deployment" {
  source        = "../../stacks/modules/panos/operations/commit_push"
  device_groups = var.device_groups
  templates = { for key, item in local.template_stacks : key => {
    templates = item.templates
    stack     = item.name
    serials   = item.serials
  } }
}

# Apply candidate configuration and any device overrides before committing.
# Commit to Panorama before ANY push, unless the changes are already committed:
# palo dev apply -invoke='module.deployment.action.panos_commit.all'
# .all performs a FULL Panorama commit of all administrators' pending changes,
# including changes outside this environment. It does not push to firewalls.
# .this["group/template"] is a PARTIAL commit scoped to that target's containers.
# Replace apply with plan in any invocation below to preview it.
#
# Template only (var.template_stacks key; requires assigned serials):
# palo dev apply -invoke='module.deployment.action.panos_push_to_devices.templates["spoke"]'
# Policy only (var.device_groups key; requires directly assigned serials):
# palo dev apply -invoke='module.deployment.action.panos_push_to_devices.policies["spoke"]'
# Push a child group to include its inherited parent policies.
#
# Combined targets use device-group/template keys and their shared serials.
# Commit first, then push separately after the commit succeeds:
# palo dev apply -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
# palo dev apply -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
# Alternatively, commit and push the target in one action:
# palo dev apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
#
# Alternatively fter committing, push every combined target:
# palo dev push-all --dry-run
# palo dev push-all
# push-all is a Python CLI command in src/palo_cli/push_all.py. It reads
# module.deployment.deployment_items and invokes the combined push actions
# sequentially. The PAN-OS provider performs the API calls. No automatic commit.
