module "addresses" {
  source = "../../../modules/panos/objects/address"
  items = {
    site_a_mgmt = {
      name       = "site-a-mgmt"
      ip_netmask = "10.1.20.0/24"
      location   = { device_group = { name = var.item.device_group } }
    }
    site_b_mgmt = {
      name       = "site-b-mgmt"
      ip_netmask = "10.2.20.0/24"
      location   = { device_group = { name = var.item.device_group } }
    }
    site_c_mgmt = {
      name       = "site-c-mgmt"
      ip_netmask = "10.3.20.0/24"
      location   = { device_group = { name = var.item.device_group } }
    }
  }
}

module "address_groups" {
  source = "../../../modules/panos/objects/address_group"
  items = {
    site_all_mgmt = {
      name     = "site-all-mgmt"
      location = { device_group = { name = var.item.device_group } }
      static = [
        module.addresses.names.site_a_mgmt,
        module.addresses.names.site_b_mgmt,
        module.addresses.names.site_c_mgmt,
      ]
    }
  }
}

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
        name                  = "allow-gre-management"
        source_zones          = [var.item.wan_zone]
        destination_zones     = [var.item.mgmt_zone]
        source_addresses      = var.item.gre_endpoints
        destination_addresses = var.item.gre_endpoints
        applications          = ["gre"]
        services              = ["application-default"]
        action                = "allow"
        log_end               = true
      },
      {
        name                  = "allow-bgp-management"
        source_zones          = [var.item.mgmt_zone]
        destination_zones     = [var.item.mgmt_zone]
        source_addresses      = ["any"]
        destination_addresses = ["any"]
        applications          = ["bgp"]
        services              = ["application-default"]
        action                = "allow"
        log_end               = true
      },
      {
        name                  = "allow-tcp-22"
        source_zones          = [var.item.mgmt_zone]
        destination_zones     = [var.item.mgmt_zone]
        source_addresses      = [module.address_groups.names.site_all_mgmt]
        destination_addresses = [module.address_groups.names.site_all_mgmt]
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
