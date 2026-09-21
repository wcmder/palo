module "device_groups" {
  source = "../../stacks/dev/device_groups"
  items = { for name, group in var.device_groups : name => merge(group, {
    device_group = name
  }) }
}

module "spoke_template" {
  source = "../../stacks/dev/spoke_template"
  item   = local.templates.spoke
}

# Common policies use explicit tfvars inputs, independent of network templates.
module "common_policies" {
  source = "../../stacks/dev/policies/common"
  item = merge(var.policies.common, {
    device_group = module.device_groups.names[var.policies.common.device_group]
  })
}
