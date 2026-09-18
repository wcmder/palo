module "device_grp" {
  source = "../../stacks/lab/device_grps"
  items = { for name, group in var.device_groups : name => merge(group, {
    device_group = name
  }) }
}

module "templates" {
  source = "../../stacks/lab/spoke_template"
  items  = var.templates
}
