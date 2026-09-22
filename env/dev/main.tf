module "device_groups" {
  source = "../../stacks/dev/device_groups"
  items = { for name, group in var.device_groups : name => merge(group, {
    device_group = name
  }) }
}

module "common_template" {
  source = "../../stacks/dev/templates/shared/common"
  item   = local.templates.common
}

module "spoke_stack" {
  source = "../../stacks/dev/templates/spoke/stacks"
  item   = local.template_stacks.spoke
}

# Common policies use explicit tfvars inputs, independent of network templates.
module "common_policies" {
  source = "../../stacks/dev/policies/common"
  item = merge(var.policies.common, {
    device_group = module.device_groups.names[var.policies.common.device_group]
  })
}
