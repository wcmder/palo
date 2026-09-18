module "device_groups" {
  source = "../../stacks/lab/device_groups"
  items = { for name, group in var.device_groups : name => merge(group, {
    device_group = name
  }) }
}

module "templates" {
  source = "../../stacks/lab/spoke_template"
  items  = var.templates
}
/*
# Opt parent groups into common policies using policy_template in root tfvars.
module "common_policies" {
  source = "../../stacks/lab/policies/common"
  items = { for name, group in var.device_groups : name => {
    device_group  = module.device_groups.names[name]
    lan_zone      = var.templates[group.policy_template].var.lan_zone
    wan_zone      = var.templates[group.policy_template].var.wan_zone
    wan_interface = var.templates[group.policy_template].var.wan_interface
  } if try(group.policy_template, null) != null }
}
*/
