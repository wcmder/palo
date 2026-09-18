# Reusable across stacks whose items have device_group and serials fields.
# Group serial lists by Panorama name so each device group is managed once.
locals {
  device_group_members = {
    for key, item in var.items : item.device_group => try(item.serials, [])...
  }
}

module "device_groups" {
  source = "../../../modules/panos/panorama/device_group"
  items = {
    for name, serial_lists in local.device_group_members : name => {
      name        = name
      description = "Terraform-managed device group"
      location    = { panorama = {} }
      # Assign whole firewalls; omit the explicit VSYS list for provider 2.0.13.
      devices = [for serial in sort(distinct(flatten(serial_lists))) : {
        name = serial
      }]
    }
  }
}

