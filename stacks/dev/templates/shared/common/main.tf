module "templates" {
  source = "../../../../modules/panos/panorama/template"
  items = { template = {
    name         = var.item.name
    description  = var.item.description
    default_vsys = "vsys1"
    location     = { panorama = {} }
  } }
}
