module "templates" {
  source = "../../../../modules/panos/panorama/template"
  items = { template = {
    name         = var.item.name
    description  = var.item.description
    default_vsys = "vsys1"
    location     = { panorama = {} }
  } }
}

module "variables" {
  source = "../../../../modules/panos/panorama/template_variable"
  items = {
    local_bgp_asn = {
      name     = "$local_bgp_asn"
      location = { template = { name = module.templates.names.template } }
      type     = { as_number = var.network.local_bgp_asn }
    }
    bgp_router_id = {
      name     = "$bgp_router_id"
      location = { template = { name = module.templates.names.template } }
      type     = { ip_netmask = var.network.bgp_router_id }
    }
    spoke_a_remote_bgp_asn = {
      name     = "$spoke_a_remote_bgp_asn"
      location = { template = { name = module.templates.names.template } }
      type     = { as_number = var.network.spoke_a_remote_bgp_asn }
    }
    spoke_a_remote_bgp_peer_ip = {
      name     = "$spoke_a_remote_bgp_peer_ip"
      location = { template = { name = module.templates.names.template } }
      type = {
        ip_netmask = var.network.spoke_a_remote_bgp_peer_ip
      }
    }
    spoke_b_remote_bgp_asn = {
      name     = "$spoke_b_remote_bgp_asn"
      location = { template = { name = module.templates.names.template } }
      type     = { as_number = var.network.spoke_b_remote_bgp_asn }
    }
    spoke_b_remote_bgp_peer_ip = {
      name     = "$spoke_b_remote_bgp_peer_ip"
      location = { template = { name = module.templates.names.template } }
      type = {
        ip_netmask = var.network.spoke_b_remote_bgp_peer_ip
      }
    }
    spoke_a_tunnel_ip = {
      name     = "$spoke_a_tunnel_ip"
      location = { template = { name = module.templates.names.template } }
      type     = { ip_netmask = var.network.spoke_a_tunnel_ip }
    }
    spoke_b_tunnel_ip = {
      name     = "$spoke_b_tunnel_ip"
      location = { template = { name = module.templates.names.template } }
      type     = { ip_netmask = var.network.spoke_b_tunnel_ip }
    }
    wan_ip = {
      name        = "$wan_ip"
      description = "WAN interface IPv4 address and prefix length"
      location    = { template = { name = module.templates.names["template"] } }
      type        = { ip_netmask = var.network.wan_ip }
    }
    lan_ip = {
      name        = "$lan_ip"
      description = "LAN subinterface IPv4 address and prefix length"
      location    = { template = { name = module.templates.names["template"] } }
      type        = { ip_netmask = var.network.lan_ip }
    }
    mgmt_ip = {
      name        = "$mgmt_ip"
      description = "Management subinterface IPv4 address and prefix length"
      location    = { template = { name = module.templates.names["template"] } }
      type        = { ip_netmask = var.network.mgmt_ip }
    }
    default_gateway = {
      name        = "$default_gateway"
      description = "WAN next hop for the IPv4 default route"
      location    = { template = { name = module.templates.names["template"] } }
      type        = { ip_netmask = var.network.default_gateway }
    }
  }
}

module "interface_management_profiles" {
  source = "../../../../modules/panos/network/interface_management_profile"
  items = {
    wan = merge(var.item.interface_management_profiles.wan, {
      location = { template = { name = module.templates.names["template"] } }
    })
    lan = merge(var.item.interface_management_profiles.lan, {
      location = { template = { name = module.templates.names["template"] } }
    })
    mgmt = merge(var.item.interface_management_profiles.mgmt, {
      location = { template = { name = module.templates.names["template"] } }
    })
  }
}

module "interfaces" {
  source = "../../../../modules/panos/network/ethernet"
  items = {
    wan = {
      name    = var.network.wan_interface
      comment = "WAN interface"
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      layer3 = {
        ips = [{ name = module.variables.names["wan_ip"] }]
        interface_management_profile = (
          module.interface_management_profiles.names["wan"]
        )
      }
    }
    lan = {
      name    = var.network.lan_interface
      comment = "LAN interface"
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      layer3 = {}
    }
  }
}

module "subinterfaces" {
  source = "../../../../modules/panos/network/ethernet_layer3_subinterface"
  items = {
    mgmt = {
      name = format(
        "%s.%s",
        module.interfaces.names["lan"],
        var.network.mgmt_subinterface_tag
      )
      parent = module.interfaces.names["lan"]
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      tag     = var.network.mgmt_subinterface_tag
      comment = "Management subinterface"
      ip      = [{ name = module.variables.names["mgmt_ip"] }]
      interface_management_profile = (
        module.interface_management_profiles.names["mgmt"]
      )
    }
    lan = {
      name = format(
        "%s.%s",
        module.interfaces.names["lan"],
        var.network.lan_subinterface_tag
      )
      parent = module.interfaces.names["lan"]
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      tag     = var.network.lan_subinterface_tag
      comment = "LAN subinterface"
      ip      = [{ name = module.variables.names["lan_ip"] }]
      interface_management_profile = (
        module.interface_management_profiles.names["lan"]
      )
    }
  }
}

# WAN and LAN profiles are supplied explicitly by the root configuration.
module "zone_protection_profiles" {
  source = "../../../../modules/panos/network/zone_protection_profile"
  items = {
    wan = merge(var.item.zone_protection_profiles.wan, {
      location = { template = { name = module.templates.names["template"] } }
    })
    lan = merge(var.item.zone_protection_profiles.lan, {
      location = { template = { name = module.templates.names["template"] } }
    })
  }
}

module "zones" {
  source = "../../../../modules/panos/network/zone"
  items = {
    wan = {
      name = var.network.wan_zone
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      network = {
        layer3                  = [module.interfaces.names["wan"]]
        zone_protection_profile = module.zone_protection_profiles.names["wan"]
      }
    }
    mgmt = {
      name = var.network.mgmt_zone
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      network = { layer3 = [
        module.subinterfaces.names.mgmt,
        module.tunnel_interfaces.names.spoke_a,
        module.tunnel_interfaces.names.spoke_b,
      ] }
    }
    lan = {
      name = var.network.lan_zone
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      network = {
        layer3                  = [module.subinterfaces.names["lan"]]
        zone_protection_profile = module.zone_protection_profiles.names["lan"]
      }
    }
  }
}

module "routers" {
  source = "../../../../modules/panos/network/virtual_router"
  items = {
    mgmt = {
      name = var.network.mgmt_virtual_router
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      interfaces = [
        module.subinterfaces.names.mgmt,
        module.tunnel_interfaces.names.spoke_a,
        module.tunnel_interfaces.names.spoke_b,
      ]
      protocol = {
        redist_profile = [{
          name     = "mgmt-connected"
          priority = 10
          action   = { redist = {} }
          filter = {
            type      = ["connect"]
            interface = [module.subinterfaces.names.mgmt]
          }
        }]
        bgp = {
          enable               = true
          install_route        = true
          reject_default_route = true
          router_id            = module.variables.names.bgp_router_id
          local_as             = module.variables.names.local_bgp_asn
          auth_profile = [
            {
              name   = "spoke_a-auth"
              secret = var.network.spoke_a_bgp_password
            },
            {
              name   = "spoke_b-auth"
              secret = var.network.spoke_b_bgp_password
            },
          ]
          peer_group = [
            {
              name   = "spoke_peers"
              enable = true
              type = { ebgp = {
                export_nexthop    = "use-self"
                import_nexthop    = "original"
                remove_private_as = false
              } }
              peer = [
                {
                  name    = "spoke_a"
                  enable  = true
                  peer_as = module.variables.names.spoke_a_remote_bgp_asn
                  local_address = {
                    interface = module.tunnel_interfaces.names.spoke_a
                    ip        = module.variables.names.spoke_a_tunnel_ip
                  }
                  peer_address = {
                    ip = module.variables.names.spoke_a_remote_bgp_peer_ip
                  }
                  connection_options = {
                    authentication = "spoke_a-auth"
                  }
                },
                {
                  name    = "spoke_b"
                  enable  = true
                  peer_as = module.variables.names.spoke_b_remote_bgp_asn
                  local_address = {
                    interface = module.tunnel_interfaces.names.spoke_b
                    ip        = module.variables.names.spoke_b_tunnel_ip
                  }
                  peer_address = {
                    ip = module.variables.names.spoke_b_remote_bgp_peer_ip
                  }
                  connection_options = {
                    authentication = "spoke_b-auth"
                  }
                }
              ]
            }
          ]
          redist_rules = [{
            name                      = "mgmt-connected"
            enable                    = true
            address_family_identifier = "ipv4"
            route_table               = "unicast"
            set_origin                = "igp"
          }]
        }
      }
    }
    # Existing routers must be imported before Terraform manages membership.
    # Changing the name of a router already in state is not an adoption.
    data = {
      name = var.network.data_virtual_router
      location = { template = {
        name = module.templates.names["template"]
        vsys = "vsys1"
      } }
      interfaces = [
        module.interfaces.names["wan"],
        module.subinterfaces.names["lan"]
      ]
    }
  }
}

module "routes" {
  source = "../../../../modules/panos/network/static_route_ipv4"
  items = {
    default = {
      name = "default"
      location = { template = {
        name = module.templates.names["template"]
      } }
      virtual_router = module.routers.names["data"]
      destination    = "0.0.0.0/0"
      interface      = module.interfaces.names["wan"]
      metric         = 10
      nexthop = {
        ip_address = module.variables.names["default_gateway"]
      }
      route_table = { unicast = {} }
    }
  }
}

module "management_profiles" {
  source = "../../../../modules/panos/network/interface_management_profile"
  items = { tunnel = {
    name     = "gre-ping"
    location = { template = { name = module.templates.names.template } }
    ping     = true
  } }
}

module "tunnel_interfaces" {
  source = "../../../../modules/panos/network/tunnel_interface"
  items = {
    spoke_a = {
      name = var.network.spoke_a_interface
      location = { template = {
        name = module.templates.names.template
        vsys = "vsys1"
      } }
      ip = [{
        name = module.variables.names.spoke_a_tunnel_ip
      }]
      mtu                          = 1476
      interface_management_profile = module.management_profiles.names.tunnel
    }
    spoke_b = {
      name = var.network.spoke_b_interface
      location = { template = {
        name = module.templates.names.template
        vsys = "vsys1"
      } }
      ip = [{
        name = module.variables.names.spoke_b_tunnel_ip
      }]
      mtu                          = 1476
      interface_management_profile = module.management_profiles.names.tunnel
    }
  }
}

module "gre_tunnels" {
  source = "../../../../modules/panos/network/gre_tunnel"
  items = {
    spoke_a = {
      name     = "gre-to-spoke-a"
      location = { template = { name = module.templates.names.template } }
      local_address = {
        interface = module.interfaces.names.wan
        ip        = module.variables.names.wan_ip
      }
      peer_address     = { ip = var.network.spoke_a_wan_ip }
      tunnel_interface = module.tunnel_interfaces.names.spoke_a
      keep_alive       = { enable = true }
    }
    spoke_b = {
      name     = "gre-to-spoke-b"
      location = { template = { name = module.templates.names.template } }
      local_address = {
        interface = module.interfaces.names.wan
        ip        = module.variables.names.wan_ip
      }
      peer_address     = { ip = var.network.spoke_b_wan_ip }
      tunnel_interface = module.tunnel_interfaces.names.spoke_b
      keep_alive       = { enable = true }
    }
  }
}
