# Preserve all child configuration fields, including future resource attributes.
module "policy" {
  source = "./policy"
  items = { for key, item in var.items : key => merge(item.policy, {
    serials = try(item.serials, [])
  }) }
}

module "template" {
  source = "./template"
  items = { for key, item in var.items : key => merge(item.template, {
    serials = try(item.serials, [])
  }) }
}
