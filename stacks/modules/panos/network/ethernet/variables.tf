variable "items" {
  description = "Resources keyed by stable logical keys. Each item supplies its own location."
  type = map(object({
    aggregate_group = optional(string)
    comment         = optional(string)
    decrypt_mirror = optional(object({
    }))
    ha = optional(object({
    }))
    lacp = optional(object({
      port_priority = optional(number)
    }))
    layer2 = optional(object({
      lldp = optional(object({
        enable = optional(bool)
        high_availability = optional(object({
          passive_pre_negotiation = optional(bool)
        }))
        profile = optional(string)
      }))
      netflow_profile = optional(string)
    }))
    layer3 = optional(object({
      adjust_tcp_mss = optional(object({
        enable              = optional(bool)
        ipv4_mss_adjustment = optional(number)
        ipv6_mss_adjustment = optional(number)
      }))
      arp = optional(list(object({
        hw_address = optional(string)
        name       = string
      })))
      bonjour = optional(object({
        enable    = optional(bool)
        group_id  = optional(number)
        ttl_check = optional(bool)
      }))
      cluster_interconnect = optional(bool)
      ddns_config = optional(object({
        ddns_cert_profile    = optional(string)
        ddns_enabled         = optional(bool)
        ddns_hostname        = optional(string)
        ddns_ip              = optional(list(string))
        ddns_ipv6            = optional(list(string))
        ddns_update_interval = optional(number)
        ddns_vendor          = optional(string)
        ddns_vendor_config = optional(list(object({
          name  = string
          value = optional(string)
        })))
      }))
      decrypt_forward = optional(bool)
      df_ignore       = optional(bool)
      dhcp_client = optional(object({
        create_default_route = optional(bool)
        default_route_metric = optional(number)
        enable               = optional(bool)
        send_hostname = optional(object({
          enable   = optional(bool)
          hostname = optional(string)
        }))
      }))
      interface_management_profile = optional(string)
      ips = optional(list(object({
        name          = string
        sdwan_gateway = optional(string)
      })))
      ipv6 = optional(object({
        addresses = optional(list(object({
          advertise = optional(object({
            auto_config_flag   = optional(bool)
            enable             = optional(bool)
            onlink_flag        = optional(bool)
            preferred_lifetime = optional(string)
            valid_lifetime     = optional(string)
          }))
          anycast = optional(object({
          }))
          enable_on_interface = optional(bool)
          name                = string
          prefix = optional(object({
          }))
        })))
        dhcp_client = optional(object({
          accept_ra_route      = optional(bool)
          default_route_metric = optional(number)
          enable               = optional(bool)
          neighbor_discovery = optional(object({
            dad_attempts = optional(number)
            dns_server = optional(object({
              enable = optional(bool)
              source = optional(object({
                dhcpv6 = optional(object({
                }))
                manual = optional(object({
                  server = optional(list(object({
                    lifetime = optional(number)
                    name     = string
                  })))
                }))
              }))
            }))
            dns_suffix = optional(object({
              enable = optional(bool)
              source = optional(object({
                dhcpv6 = optional(object({
                }))
                manual = optional(object({
                  suffix = optional(list(object({
                    lifetime = optional(number)
                    name     = string
                  })))
                }))
              }))
            }))
            enable_dad         = optional(bool)
            enable_ndp_monitor = optional(bool)
            neighbor = optional(list(object({
              hw_address = optional(string)
              name       = string
            })))
            ns_interval    = optional(number)
            reachable_time = optional(number)
          }))
          preference = optional(string)
          prefix_delegation = optional(object({
            enable = optional(object({
              no = optional(object({
              }))
              yes = optional(object({
                pfx_pool_name   = optional(string)
                prefix_len      = optional(number)
                prefix_len_hint = optional(bool)
              }))
            }))
          }))
          v6_options = optional(object({
            duid_type = optional(string)
            enable = optional(object({
              no = optional(object({
              }))
              yes = optional(object({
                non_temp_addr = optional(bool)
                temp_addr     = optional(bool)
              }))
            }))
            rapid_commit          = optional(bool)
            support_srvr_reconfig = optional(bool)
          }))
        }))
        enabled = optional(bool)
        inherited = optional(object({
          assign_addr = optional(list(object({
            name = string
            type = optional(object({
              gua = optional(object({
                advertise = optional(object({
                  auto_config_flag = optional(bool)
                  enable           = optional(bool)
                  onlink_flag      = optional(bool)
                }))
                enable_on_interface = optional(bool)
                pool_type = optional(object({
                  dynamic = optional(object({
                  }))
                  dynamic_id = optional(object({
                    identifier = optional(number)
                  }))
                }))
                prefix_pool = optional(string)
              }))
              ula = optional(object({
                addresses = optional(string)
                advertise = optional(object({
                  auto_config_flag   = optional(bool)
                  enable             = optional(bool)
                  onlink_flag        = optional(bool)
                  preferred_lifetime = optional(string)
                  valid_lifetime     = optional(string)
                }))
                anycast             = optional(bool)
                enable_on_interface = optional(bool)
                prefix              = optional(bool)
              }))
            }))
          })))
          enable = optional(bool)
          neighbor_discovery = optional(object({
            dad_attempts = optional(number)
            dns_server = optional(object({
              enable = optional(bool)
              source = optional(object({
                dhcpv6 = optional(object({
                  prefix_pool = optional(string)
                }))
                manual = optional(object({
                  server = optional(list(object({
                    lifetime = optional(number)
                    name     = string
                  })))
                }))
              }))
            }))
            dns_suffix = optional(object({
              enable = optional(bool)
              source = optional(object({
                dhcpv6 = optional(object({
                  prefix_pool = optional(string)
                }))
                manual = optional(object({
                  suffix = optional(list(object({
                    lifetime = optional(number)
                    name     = string
                  })))
                }))
              }))
            }))
            enable_dad         = optional(bool)
            enable_ndp_monitor = optional(bool)
            neighbor = optional(list(object({
              hw_address = optional(string)
              name       = string
            })))
            ns_interval    = optional(number)
            reachable_time = optional(number)
            router_advertisement = optional(object({
              enable                   = optional(bool)
              enable_consistency_check = optional(bool)
              hop_limit                = optional(string)
              lifetime                 = optional(number)
              link_mtu                 = optional(string)
              managed_flag             = optional(bool)
              max_interval             = optional(number)
              min_interval             = optional(number)
              other_flag               = optional(bool)
              reachable_time           = optional(string)
              retransmission_timer     = optional(string)
              router_preference        = optional(string)
            }))
          }))
        }))
        interface_id = optional(string)
        neighbor_discovery = optional(object({
          dad_attempts       = optional(number)
          enable_dad         = optional(bool)
          enable_ndp_monitor = optional(bool)
          neighbor = optional(list(object({
            hw_address = optional(string)
            name       = string
          })))
          ns_interval    = optional(number)
          reachable_time = optional(number)
          router_advertisement = optional(object({
            dns_support = optional(object({
              enable = optional(bool)
              server = optional(list(object({
                lifetime = optional(number)
                name     = string
              })))
              suffix = optional(list(object({
                lifetime = optional(number)
                name     = string
              })))
            }))
            enable                   = optional(bool)
            enable_consistency_check = optional(bool)
            hop_limit                = optional(string)
            lifetime                 = optional(number)
            link_mtu                 = optional(string)
            managed_flag             = optional(bool)
            max_interval             = optional(number)
            min_interval             = optional(number)
            other_flag               = optional(bool)
            reachable_time           = optional(string)
            retransmission_timer     = optional(string)
            router_preference        = optional(string)
          }))
        }))
      }))
      lldp = optional(object({
        enable = optional(bool)
        high_availability = optional(object({
          passive_pre_negotiation = optional(bool)
        }))
        profile = optional(string)
      }))
      mtu = optional(number)
      ndp_proxy = optional(object({
        addresses = optional(list(object({
          name   = string
          negate = optional(bool)
        })))
        enabled = optional(bool)
      }))
      netflow_profile = optional(string)
      pppoe = optional(object({
        access_concentrator  = optional(string)
        authentication       = optional(string)
        create_default_route = optional(bool)
        default_route_metric = optional(number)
        enable               = optional(bool)
        passive = optional(object({
          enable = optional(bool)
        }))
        password = optional(string)
        service  = optional(string)
        static_address = optional(object({
          ips = optional(string)
        }))
        username = optional(string)
      }))
      sdwan_link_settings = optional(object({
        enable                  = optional(bool)
        sdwan_interface_profile = optional(string)
        upstream_nat = optional(object({
          ddns = optional(object({
          }))
          enable = optional(bool)
          static_ip = optional(object({
            fqdn       = optional(string)
            ip_address = optional(string)
          }))
        }))
      }))
      traffic_interconnect   = optional(bool)
      untagged_sub_interface = optional(bool)
    }))
    link_duplex = optional(string)
    link_speed  = optional(string)
    link_state  = optional(string)
    location = object({
      ngfw = optional(object({
        ngfw_device = optional(string)
      }))
      shared = optional(object({
      }))
      template = optional(object({
        name            = optional(string)
        ngfw_device     = optional(string)
        panorama_device = optional(string)
        vsys            = optional(string)
      }))
      template_stack = optional(object({
        name            = optional(string)
        ngfw_device     = optional(string)
        panorama_device = optional(string)
      }))
    })
    log_card = optional(object({
      default_gateway      = optional(string)
      ip_address           = optional(string)
      ipv6_address         = optional(string)
      ipv6_default_gateway = optional(string)
      netmask              = optional(string)
    }))
    name = string
    poe = optional(object({
      enabled            = optional(bool)
      poe_reserved_power = optional(number)
    }))
    tap = optional(object({
      netflow_profile = optional(string)
    }))
    virtual_wire = optional(object({
      lacp = optional(object({
        high_availability = optional(object({
          passive_pre_negotiation = optional(bool)
        }))
      }))
      lldp = optional(object({
        enable = optional(bool)
        high_availability = optional(object({
          passive_pre_negotiation = optional(bool)
        }))
        profile = optional(string)
      }))
      netflow_profile = optional(string)
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for item in values(var.items) : length([for scope, value in item.location : scope if value != null]) == 1])
    error_message = "Each item must set exactly one location scope."
  }

  validation {
    condition     = length(distinct([for item in values(var.items) : item.name])) == length(var.items)
    error_message = "Names must be unique within a module call to avoid ambiguous resource names; use separate module calls for duplicate names in different scopes."
  }
}
