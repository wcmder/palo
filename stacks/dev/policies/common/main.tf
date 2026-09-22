# One owner for each parent pre-rulebase. Rule order is intentional.
module "services" {
  source = "../../../modules/panos/objects/service"
  items = {
    tcp_22 = {
      name     = "tcp-22"
      location = { device_group = { name = var.item.device_group } }
      protocol = { tcp = { destination_port = "22" } }
    }
  }
}

module "nat" {
  source = "../../../modules/panos/policy/nat"
  items = { common = {
    location = { device_group = { name = var.item.device_group, rulebase = "pre-rulebase" } }
    rules = [{
      name                  = "wan-interface-snat"
      description           = "Source NAT outbound traffic to the WAN interface address; security controls permitted traffic."
      nat_type              = "ipv4"
      source_zones          = ["any"]
      destination_zone      = [var.item.wan_zone]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      to_interface          = var.item.wan_interface
      service               = "any"
      source_translation = {
        dynamic_ip_and_port = {
          interface_address = { interface = var.item.wan_interface }
        }
      }
    }]
  } }
}

module "security-pre" {
  source = "../../../modules/panos/policy/security"
  items = { common = {
    location = { device_group = { name = var.item.device_group, rulebase = "pre-rulebase" } }
    rules = [
      {
        name                  = "allow-tcp-22"
        source_zones          = [var.item.lan_zone, var.item.wan_zone]
        destination_zones     = [var.item.lan_zone, var.item.wan_zone]
        source_addresses      = ["any"]
        destination_addresses = ["any"]
        applications          = ["any"]
        services              = [module.services.names["tcp_22"]]
        action                = "allow"
        log_end               = true
      },
      {
        name                  = "allow-icmp"
        source_zones          = ["any"]
        destination_zones     = ["any"]
        source_addresses      = ["any"]
        destination_addresses = ["any"]
        applications          = ["icmp", "ping"]
        services              = ["application-default"]
        action                = "allow"
        log_end               = true
      }
    ]
  } }
}


module "security-post" {
  source = "../../../modules/panos/policy/security"
  items = { common = {
    location = { device_group = { name = var.item.device_group, rulebase = "post-rulebase" } }
    rules = [
      {
        name                  = "default-deny"
        source_zones          = ["any"]
        destination_zones     = ["any"]
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

# Default rules run after pre-rules, local rules and post-rules.
module "default_security" {
  source = "../../../modules/panos/policy/default_security"
  items = { common = {
    location = { device_group = { name = var.item.device_group } }
    rules    = var.item.default_security_rules
  } }
}
