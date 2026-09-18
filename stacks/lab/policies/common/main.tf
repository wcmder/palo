# One owner for each parent pre-rulebase. Rule order is intentional.
module "services" {
  for_each = var.items
  source   = "../../../modules/panos/objects/service"
  items = {
    tcp_22 = {
      name     = "tcp-22"
      location = { device_group = { name = each.value.device_group } }
      protocol = { tcp = { destination_port = "22" } }
    }
  }
}

module "nat" {
  source = "../../../modules/panos/policy/nat"
  items = { for key, item in var.items : key => {
    location = { device_group = { name = item.device_group, rulebase = "pre-rulebase" } }
    rules = [{
      name                  = "wan-interface-snat"
      description           = "Source NAT outbound traffic to the WAN interface address; security controls permitted traffic."
      nat_type              = "ipv4"
      source_zones          = ["any"]
      destination_zone      = [item.wan_zone]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      to_interface          = item.wan_interface
      service               = "any"
      source_translation = {
        dynamic_ip_and_port = {
          interface_address = { interface = item.wan_interface }
        }
      }
    }]
  } }
}

module "security" {
  source = "../../../modules/panos/policy/security"
  items = { for key, item in var.items : key => {
    location = { device_group = { name = item.device_group, rulebase = "pre-rulebase" } }
    rules = [
      {
        name                  = "allow-lan-wan-tcp-22"
        source_zones          = [item.lan_zone]
        destination_zones     = [item.wan_zone]
        source_addresses      = ["any"]
        destination_addresses = ["any"]
        applications          = ["any"]
        services              = [module.services[key].names["tcp_22"]]
        action                = "allow"
        log_end               = true
      },
      {
        name                  = "allow-lan-wan-icmp"
        source_zones          = [item.lan_zone]
        destination_zones     = [item.wan_zone]
        source_addresses      = ["any"]
        destination_addresses = ["any"]
        applications          = ["icmp", "ping"]
        services              = ["application-default"]
        action                = "allow"
        log_end               = true
      },
      {
        name                  = "deny-other-lan-wan"
        source_zones          = [item.lan_zone]
        destination_zones     = [item.wan_zone]
        source_addresses      = ["any"]
        destination_addresses = ["any"]
        applications          = ["any"]
        services              = ["any"]
        action                = "deny"
        log_end               = true
      }
    ]
  } }
}
