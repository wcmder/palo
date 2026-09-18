module "device_groups" {
  source = "../../stacks/lab/device_groups"
  items = { for name, group in var.device_groups : name => merge(group, {
    device_group = name
  }) }
}

module "templates" {
  source = "../../stacks/lab/spoke_template"
  items  = local.templates
}

# Common policies use explicit tfvars inputs, independent of network templates.
module "common_policies" {
  source = "../../stacks/lab/policies/common"
  items = { for key, policy in try(var.policies.common, {}) : key => merge(policy, {
    device_group = module.device_groups.names[policy.device_group]
  }) }
}
