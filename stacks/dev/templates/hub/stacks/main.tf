module "template_stacks" {
  source = "../../../../modules/panos/panorama/template_stack"
  items = {
    template = {
      name         = var.item.name
      description  = var.item.description
      default_vsys = "vsys1"
      location     = { panorama = {} }
      templates    = var.item.templates
      devices      = [for serial in var.item.serials : { name = serial }]
    }
  }
}
