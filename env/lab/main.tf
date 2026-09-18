module "spokes" {
  source = "../../stacks/lab/spoke"
  items  = var.spokes
}
