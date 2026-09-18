# Preserve the existing managed resources while separating policy and templates.
moved {
  from = module.spokes.module.policy.module.device_groups
  to   = module.policy.module.device_groups
}
moved {
  from = module.spokes.module.template
  to   = module.templates
}

# Preserve addresses from the previous root module label.
moved {
  from = module.policy
  to   = module.device_grp
}
