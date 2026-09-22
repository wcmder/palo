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
  source         = "../../stacks/dev/templates/spoke/network"
  item           = local.templates.spoke
  network        = local.networks.spoke
  stack          = module.spoke_stack.names.template
  mgmt_interface = module.common_template.names.subinterfaces.mgmt
}

module "hub_template" {
  source         = "../../stacks/dev/templates/hub/network"
  item           = local.templates.hub
  network        = local.networks.hub
  stack          = module.hub_stack.names.template
  mgmt_interface = module.common_template.names.subinterfaces.mgmt
}
