module "panorama" {
  source = "../../stacks/lab/panorama"
  sites  = var.sites
}

module "spokes" {
  source = "../../stacks/lab/spoke"
  items  = var.spokes
}
