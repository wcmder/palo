module "device_groups" {
  source = "../../stacks/dev/device_groups"
  items  = var.device_groups
}

# Common policies use explicit tfvars inputs, independent of network templates.
module "common_policies" {
  source = "../../stacks/dev/policies/common"
  item   = var.policies.common

  depends_on = [module.device_groups]
}

module "common_template" {
  source = "../../stacks/dev/templates/shared/common"
  item   = local.templates.common
}

module "spoke_stack" {
  source = "../../stacks/dev/templates/spoke/stacks"
  item   = local.template_stacks.spoke
}

module "hub_stack" {
  source = "../../stacks/dev/templates/spoke/stacks"
  item   = local.template_stacks.hub
}

module "spoke_template" {
  source  = "../../stacks/dev/templates/spoke/network"
  item    = local.templates.spoke
  network = var.templates.spoke.var
}

module "hub_template" {
  source  = "../../stacks/dev/templates/hub/network"
  item    = local.templates.hub
  network = var.templates.hub.var
}
