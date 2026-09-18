resource "panos_ethernet_interface" "this" {
  for_each        = var.items
  aggregate_group = each.value.aggregate_group
  comment         = each.value.comment
  decrypt_mirror  = each.value.decrypt_mirror
  ha              = each.value.ha
  lacp            = each.value.lacp
  layer2          = each.value.layer2
  layer3          = each.value.layer3
  link_duplex     = each.value.link_duplex
  link_speed      = each.value.link_speed
  link_state      = each.value.link_state
  location        = each.value.location
  log_card        = each.value.log_card
  name            = each.value.name
  poe             = each.value.poe
  tap             = each.value.tap
  virtual_wire    = each.value.virtual_wire
}
