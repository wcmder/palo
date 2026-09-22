module "common" {
  source = "../../../../../stacks/dev/templates/shared/common"
  item = {
    zone_protection_profiles = {
      wan = { name = "test-wan-protection" }
      lan = { name = "test-lan-protection" }
    }
    name = "test-common"

    description = "Terraform-managed spoke"
    interface_management_profiles = {
      wan  = { name = "wan-ping", ping = true }
      lan  = { name = "lan-ping", ping = true }
      mgmt = { name = "mgmt-ping", ping = true }
    }
    var = {
      wan_interface         = "ethernet1/1"
      lan_interface         = "ethernet1/2"
      lan_subinterface_tag  = 20
      mgmt_subinterface_tag = 10
      mgmt_zone             = "mgmt"
      mgmt_virtual_router   = "mgmt"
      wan_zone              = "wan"
      lan_zone              = "lan"
      wan_ip                = "192.0.2.2/30"
      lan_ip                = "198.51.100.1/24"
      mgmt_ip               = "203.0.113.1/24"
      default_gateway       = "192.0.2.1"
      data_virtual_router   = "spoke-vr"
    }

  }
}

module "specific" {
  source = "../../../../../stacks/modules/panos/panorama/template"
  items = {
    template = {
      name        = "test-specific"
      description = "Stack-specific settings"
      location    = { panorama = {} }
    }
  }
}

module "first" {
  source = "../../../../../stacks/dev/templates/spoke/stacks"
  item = {
    name        = "test-first"
    description = "Common plus specific"
    templates = [
      module.specific.names.template,
      module.common.names.templates.template
    ]
    serials = ["serial-a"]
  }
}

module "second" {
  source = "../../../../../stacks/dev/templates/spoke/stacks"
  item = {
    name        = "test-second"
    description = "Common only"
    templates   = [module.common.names.templates.template]
    serials     = ["serial-b"]
  }
}
