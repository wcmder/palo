variable "items" {
  description = "Resources keyed by stable logical keys. Each item supplies its own location."
  type = map(object({
    administrative_distances = optional(object({
      ebgp        = optional(number)
      ibgp        = optional(number)
      ospf_ext    = optional(number)
      ospf_int    = optional(number)
      ospfv3_ext  = optional(number)
      ospfv3_int  = optional(number)
      rip         = optional(number)
      static      = optional(number)
      static_ipv6 = optional(number)
    }))
    ecmp = optional(object({
      algorithm = optional(object({
        balanced_round_robin = optional(object({
        }))
        ip_hash = optional(object({
          hash_seed = optional(number)
          src_only  = optional(bool)
          use_port  = optional(bool)
        }))
        ip_modulo = optional(object({
        }))
        weighted_round_robin = optional(object({
          interface = optional(list(object({
            name   = string
            weight = optional(number)
          })))
        }))
      }))
      enable             = optional(bool)
      max_paths          = optional(number)
      strict_source_path = optional(bool)
      symmetric_return   = optional(bool)
    }))
    interfaces = optional(list(string))
    location = object({
      ngfw = optional(object({
        ngfw_device = optional(string)
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
      template_stack_vsys = optional(object({
        ngfw_device     = optional(string)
        panorama_device = optional(string)
        template_stack  = optional(string)
        vsys            = optional(string)
      }))
      template_vsys = optional(object({
        ngfw_device     = optional(string)
        panorama_device = optional(string)
        template        = optional(string)
        vsys            = optional(string)
      }))
      vsys = optional(object({
        name        = optional(string)
        ngfw_device = optional(string)
      }))
    })
    multicast = optional(object({
      enable = optional(bool)
      interface_group = optional(list(object({
        description = optional(string)
        group_permission = optional(object({
          any_source_multicast = optional(list(object({
            group_address = optional(string)
            included      = optional(bool)
            name          = string
          })))
          source_specific_multicast = optional(list(object({
            group_address  = optional(string)
            included       = optional(bool)
            name           = string
            source_address = optional(string)
          })))
        }))
        igmp = optional(object({
          enable                     = optional(bool)
          immediate_leave            = optional(bool)
          last_member_query_interval = optional(number)
          max_groups                 = optional(string)
          max_query_response_time    = optional(number)
          max_sources                = optional(string)
          query_interval             = optional(number)
          robustness                 = optional(string)
          router_alert_policing      = optional(bool)
          version                    = optional(string)
        }))
        interface = optional(list(string))
        name      = string
        pim = optional(object({
          allowed_neighbors = optional(list(object({
            name = string
          })))
          assert_interval     = optional(number)
          bsr_border          = optional(bool)
          dr_priority         = optional(number)
          enable              = optional(bool)
          hello_interval      = optional(number)
          join_prune_interval = optional(number)
        }))
      })))
      route_ageout_time = optional(number)
      rp = optional(object({
        external_rp = optional(list(object({
          group_addresses = optional(list(string))
          name            = string
          override        = optional(bool)
        })))
        local_rp = optional(object({
          candidate_rp = optional(object({
            address                = optional(string)
            advertisement_interval = optional(number)
            group_addresses        = optional(list(string))
            interface              = optional(string)
            priority               = optional(number)
          }))
          static_rp = optional(object({
            address         = optional(string)
            group_addresses = optional(list(string))
            interface       = optional(string)
            override        = optional(bool)
          }))
        }))
      }))
      spt_threshold = optional(list(object({
        name      = string
        threshold = optional(string)
      })))
      ssm_address_space = optional(list(object({
        group_address = optional(string)
        included      = optional(bool)
        name          = string
      })))
    }))
    name = string
    protocol = optional(object({
      bgp = optional(object({
        allow_redist_default_route = optional(bool)
        auth_profile = optional(list(object({
          name   = string
          secret = optional(string)
        })))
        dampening_profile = optional(list(object({
          cutoff                      = optional(number)
          decay_half_life_reachable   = optional(number)
          decay_half_life_unreachable = optional(number)
          enable                      = optional(bool)
          max_hold_time               = optional(number)
          name                        = string
          reuse                       = optional(number)
        })))
        ecmp_multi_as    = optional(bool)
        enable           = optional(bool)
        enforce_first_as = optional(bool)
        global_bfd = optional(object({
          profile = optional(string)
        }))
        install_route = optional(bool)
        local_as      = optional(string)
        peer_group = optional(list(object({
          aggregated_confed_as_path = optional(bool)
          enable                    = optional(bool)
          name                      = string
          peer = optional(list(object({
            address_family_identifier = optional(string)
            bfd = optional(object({
              profile = optional(string)
            }))
            connection_options = optional(object({
              authentication = optional(string)
              hold_time      = optional(string)
              idle_hold_time = optional(number)
              incoming_bgp_connection = optional(object({
                allow       = optional(bool)
                remote_port = optional(number)
              }))
              keep_alive_interval    = optional(string)
              min_route_adv_interval = optional(number)
              multihop               = optional(number)
              open_delay_time        = optional(number)
              outgoing_bgp_connection = optional(object({
                allow      = optional(bool)
                local_port = optional(number)
              }))
            }))
            enable                            = optional(bool)
            enable_mp_bgp                     = optional(bool)
            enable_sender_side_loop_detection = optional(bool)
            local_address = optional(object({
              interface = optional(string)
              ip        = optional(string)
            }))
            max_prefixes = optional(string)
            name         = string
            peer_address = optional(object({
              fqdn = optional(string)
              ip   = optional(string)
            }))
            peer_as          = optional(string)
            peering_type     = optional(string)
            reflector_client = optional(string)
            subsequent_address_family_identifier = optional(object({
              multicast = optional(bool)
              unicast   = optional(bool)
            }))
          })))
          soft_reset_with_stored_info = optional(bool)
          type = optional(object({
            ebgp = optional(object({
              export_nexthop    = optional(string)
              import_nexthop    = optional(string)
              remove_private_as = optional(bool)
            }))
            ebgp_confed = optional(object({
              export_nexthop = optional(string)
            }))
            ibgp = optional(object({
              export_nexthop = optional(string)
            }))
            ibgp_confed = optional(object({
              export_nexthop = optional(string)
            }))
          }))
        })))
        policy = optional(object({
          aggregation = optional(object({
            address = optional(list(object({
              advertise_filters = optional(list(object({
                enable = optional(bool)
                match = optional(object({
                  address_prefix = optional(list(object({
                    exact = optional(bool)
                    name  = string
                  })))
                  as_path = optional(object({
                    regex = optional(string)
                  }))
                  community = optional(object({
                    regex = optional(string)
                  }))
                  extended_community = optional(object({
                    regex = optional(string)
                  }))
                  from_peer   = optional(list(string))
                  med         = optional(number)
                  nexthop     = optional(list(string))
                  route_table = optional(string)
                }))
                name = string
              })))
              aggregate_route_attributes = optional(object({
                as_path = optional(object({
                  none = optional(object({
                  }))
                  prepend = optional(number)
                }))
                as_path_limit = optional(number)
                community = optional(object({
                  append = optional(list(string))
                  none = optional(object({
                  }))
                  overwrite = optional(list(string))
                  remove_all = optional(object({
                  }))
                  remove_regex = optional(string)
                }))
                extended_community = optional(object({
                  append = optional(list(string))
                  none = optional(object({
                  }))
                  overwrite = optional(list(string))
                  remove_all = optional(object({
                  }))
                  remove_regex = optional(string)
                }))
                local_preference = optional(number)
                med              = optional(number)
                nexthop          = optional(string)
                origin           = optional(string)
                weight           = optional(number)
              }))
              as_set  = optional(bool)
              enable  = optional(bool)
              name    = string
              prefix  = optional(string)
              summary = optional(bool)
              suppress_filters = optional(list(object({
                enable = optional(bool)
                match = optional(object({
                  address_prefix = optional(list(object({
                    exact = optional(bool)
                    name  = string
                  })))
                  as_path = optional(object({
                    regex = optional(string)
                  }))
                  community = optional(object({
                    regex = optional(string)
                  }))
                  extended_community = optional(object({
                    regex = optional(string)
                  }))
                  from_peer   = optional(list(string))
                  med         = optional(number)
                  nexthop     = optional(list(string))
                  route_table = optional(string)
                }))
                name = string
              })))
            })))
          }))
          conditional_advertisement = optional(object({
            policy = optional(list(object({
              advertise_filters = optional(list(object({
                enable = optional(bool)
                match = optional(object({
                  address_prefix = optional(list(object({
                    name = string
                  })))
                  as_path = optional(object({
                    regex = optional(string)
                  }))
                  community = optional(object({
                    regex = optional(string)
                  }))
                  extended_community = optional(object({
                    regex = optional(string)
                  }))
                  from_peer   = optional(list(string))
                  med         = optional(number)
                  nexthop     = optional(list(string))
                  route_table = optional(string)
                }))
                name = string
              })))
              enable = optional(bool)
              name   = string
              non_exist_filters = optional(list(object({
                enable = optional(bool)
                match = optional(object({
                  address_prefix = optional(list(object({
                    name = string
                  })))
                  as_path = optional(object({
                    regex = optional(string)
                  }))
                  community = optional(object({
                    regex = optional(string)
                  }))
                  extended_community = optional(object({
                    regex = optional(string)
                  }))
                  from_peer   = optional(list(string))
                  med         = optional(number)
                  nexthop     = optional(list(string))
                  route_table = optional(string)
                }))
                name = string
              })))
              used_by = optional(list(string))
            })))
          }))
          export = optional(object({
            rules = optional(list(object({
              action = optional(object({
                allow = optional(object({
                  update = optional(object({
                    as_path = optional(object({
                      none = optional(object({
                      }))
                      prepend = optional(number)
                      remove = optional(object({
                      }))
                      remove_and_prepend = optional(number)
                    }))
                    as_path_limit = optional(number)
                    community = optional(object({
                      append = optional(list(string))
                      none = optional(object({
                      }))
                      overwrite = optional(list(string))
                      remove_all = optional(object({
                      }))
                      remove_regex = optional(string)
                    }))
                    extended_community = optional(object({
                      append = optional(list(string))
                      none = optional(object({
                      }))
                      overwrite = optional(list(string))
                      remove_all = optional(object({
                      }))
                      remove_regex = optional(string)
                    }))
                    local_preference = optional(number)
                    med              = optional(number)
                    nexthop          = optional(string)
                    origin           = optional(string)
                  }))
                }))
                deny = optional(object({
                }))
              }))
              enable = optional(bool)
              match = optional(object({
                address_prefix = optional(list(object({
                  exact = optional(bool)
                  name  = string
                })))
                as_path = optional(object({
                  regex = optional(string)
                }))
                community = optional(object({
                  regex = optional(string)
                }))
                extended_community = optional(object({
                  regex = optional(string)
                }))
                from_peer   = optional(list(string))
                med         = optional(number)
                nexthop     = optional(list(string))
                route_table = optional(string)
              }))
              name    = string
              used_by = optional(list(string))
            })))
          }))
          import = optional(object({
            rules = optional(list(object({
              action = optional(object({
                allow = optional(object({
                  dampening = optional(string)
                  update = optional(object({
                    as_path = optional(object({
                      none = optional(object({
                      }))
                      remove = optional(object({
                      }))
                    }))
                    as_path_limit = optional(number)
                    community = optional(object({
                      append = optional(list(string))
                      none = optional(object({
                      }))
                      overwrite = optional(list(string))
                      remove_all = optional(object({
                      }))
                      remove_regex = optional(string)
                    }))
                    extended_community = optional(object({
                      append = optional(list(string))
                      none = optional(object({
                      }))
                      overwrite = optional(list(string))
                      remove_all = optional(object({
                      }))
                      remove_regex = optional(string)
                    }))
                    local_preference = optional(number)
                    med              = optional(number)
                    nexthop          = optional(string)
                    origin           = optional(string)
                    weight           = optional(number)
                  }))
                }))
                deny = optional(object({
                }))
              }))
              enable = optional(bool)
              match = optional(object({
                address_prefix = optional(list(object({
                  exact = optional(bool)
                  name  = string
                })))
                as_path = optional(object({
                  regex = optional(string)
                }))
                community = optional(object({
                  regex = optional(string)
                }))
                extended_community = optional(object({
                  regex = optional(string)
                }))
                from_peer   = optional(list(string))
                med         = optional(number)
                nexthop     = optional(list(string))
                route_table = optional(string)
              }))
              name    = string
              used_by = optional(list(string))
            })))
          }))
        }))
        redist_rules = optional(list(object({
          address_family_identifier = optional(string)
          enable                    = optional(bool)
          metric                    = optional(number)
          name                      = string
          route_table               = optional(string)
          set_as_path_limit         = optional(number)
          set_community             = optional(list(string))
          set_extended_community    = optional(list(string))
          set_local_preference      = optional(number)
          set_med                   = optional(number)
          set_origin                = optional(string)
        })))
        reject_default_route = optional(bool)
        router_id            = optional(string)
        routing_options = optional(object({
          aggregate = optional(object({
            aggregate_med = optional(bool)
          }))
          as_format                = optional(string)
          confederation_member_as  = optional(string)
          default_local_preference = optional(number)
          graceful_restart = optional(object({
            enable                = optional(bool)
            local_restart_time    = optional(number)
            max_peer_restart_time = optional(number)
            stale_route_time      = optional(number)
          }))
          med = optional(object({
            always_compare_med           = optional(bool)
            deterministic_med_comparison = optional(bool)
          }))
          reflector_cluster_id = optional(string)
        }))
      }))
      ospf = optional(object({
        allow_redist_default_route = optional(bool)
        area = optional(list(object({
          interface = optional(list(object({
            authentication = optional(string)
            bfd = optional(object({
              profile = optional(string)
            }))
            dead_counts    = optional(number)
            enable         = optional(bool)
            gr_delay       = optional(number)
            hello_interval = optional(number)
            link_type = optional(object({
              broadcast = optional(object({
              }))
              p2mp = optional(object({
              }))
              p2p = optional(object({
              }))
            }))
            metric = optional(number)
            name   = string
            neighbor = optional(list(object({
              name = string
            })))
            passive             = optional(bool)
            priority            = optional(number)
            retransmit_interval = optional(number)
            transit_delay       = optional(number)
          })))
          name = string
          range = optional(list(object({
            advertise = optional(object({
            }))
            name = string
            suppress = optional(object({
            }))
          })))
          type = optional(object({
            normal = optional(object({
            }))
            nssa = optional(object({
              accept_summary = optional(bool)
              default_route = optional(object({
                advertise = optional(object({
                  metric = optional(number)
                  type   = optional(string)
                }))
                disable = optional(object({
                }))
              }))
              nssa_ext_range = optional(list(object({
                advertise = optional(object({
                }))
                name = string
                suppress = optional(object({
                }))
              })))
            }))
            stub = optional(object({
              accept_summary = optional(bool)
              default_route = optional(object({
                advertise = optional(object({
                  metric = optional(number)
                }))
                disable = optional(object({
                }))
              }))
            }))
          }))
          virtual_link = optional(list(object({
            authentication = optional(string)
            bfd = optional(object({
              profile = optional(string)
            }))
            dead_counts         = optional(number)
            enable              = optional(bool)
            hello_interval      = optional(number)
            name                = string
            neighbor_id         = optional(string)
            retransmit_interval = optional(number)
            transit_area_id     = optional(string)
            transit_delay       = optional(number)
          })))
        })))
        auth_profile = optional(list(object({
          md5 = optional(list(object({
            key       = optional(string)
            name      = string
            preferred = optional(bool)
          })))
          name     = string
          password = optional(string)
        })))
        enable = optional(bool)
        export_rules = optional(list(object({
          metric        = optional(number)
          name          = string
          new_path_type = optional(string)
          new_tag       = optional(string)
        })))
        global_bfd = optional(object({
          profile = optional(string)
        }))
        graceful_restart = optional(object({
          enable                    = optional(bool)
          grace_period              = optional(number)
          helper_enable             = optional(bool)
          max_neighbor_restart_time = optional(number)
          strict_l_s_a_checking     = optional(bool)
        }))
        reject_default_route = optional(bool)
        rfc1583              = optional(bool)
        router_id            = optional(string)
        timers = optional(object({
          lsa_interval          = optional(number)
          spf_calculation_delay = optional(number)
        }))
      }))
      ospfv3 = optional(object({
        allow_redist_default_route = optional(bool)
        area = optional(list(object({
          authentication = optional(string)
          interface = optional(list(object({
            authentication = optional(string)
            bfd = optional(object({
              profile = optional(string)
            }))
            dead_counts    = optional(number)
            enable         = optional(bool)
            gr_delay       = optional(number)
            hello_interval = optional(number)
            instance_id    = optional(number)
            link_type = optional(object({
              broadcast = optional(object({
              }))
              p2mp = optional(object({
              }))
              p2p = optional(object({
              }))
            }))
            metric = optional(number)
            name   = string
            neighbor = optional(list(object({
              name = string
            })))
            passive             = optional(bool)
            priority            = optional(number)
            retransmit_interval = optional(number)
            transit_delay       = optional(number)
          })))
          name = string
          range = optional(list(object({
            advertise = optional(object({
            }))
            name = string
            suppress = optional(object({
            }))
          })))
          type = optional(object({
            normal = optional(object({
            }))
            nssa = optional(object({
              accept_summary = optional(bool)
              default_route = optional(object({
                advertise = optional(object({
                  metric = optional(number)
                  type   = optional(string)
                }))
                disable = optional(object({
                }))
              }))
              nssa_ext_range = optional(list(object({
                advertise = optional(object({
                }))
                name = string
                suppress = optional(object({
                }))
              })))
            }))
            stub = optional(object({
              accept_summary = optional(bool)
              default_route = optional(object({
                advertise = optional(object({
                  metric = optional(number)
                }))
                disable = optional(object({
                }))
              }))
            }))
          }))
          virtual_link = optional(list(object({
            authentication = optional(string)
            bfd = optional(object({
              profile = optional(string)
            }))
            dead_counts         = optional(number)
            enable              = optional(bool)
            hello_interval      = optional(number)
            instance_id         = optional(number)
            name                = string
            neighbor_id         = optional(string)
            retransmit_interval = optional(number)
            transit_area_id     = optional(string)
            transit_delay       = optional(number)
          })))
        })))
        auth_profile = optional(list(object({
          ah = optional(object({
            md5 = optional(object({
              key = optional(string)
            }))
            sha1 = optional(object({
              key = optional(string)
            }))
            sha256 = optional(object({
              key = optional(string)
            }))
            sha384 = optional(object({
              key = optional(string)
            }))
            sha512 = optional(object({
              key = optional(string)
            }))
          }))
          esp = optional(object({
            authentication = optional(object({
              md5 = optional(object({
                key = optional(string)
              }))
              none = optional(object({
              }))
              sha1 = optional(object({
                key = optional(string)
              }))
              sha256 = optional(object({
                key = optional(string)
              }))
              sha384 = optional(object({
                key = optional(string)
              }))
              sha512 = optional(object({
                key = optional(string)
              }))
            }))
            encryption = optional(object({
              algorithm = optional(string)
              key       = optional(string)
            }))
          }))
          name = string
          spi  = optional(string)
        })))
        disable_transit_traffic = optional(bool)
        enable                  = optional(bool)
        export_rules = optional(list(object({
          metric        = optional(number)
          name          = string
          new_path_type = optional(string)
          new_tag       = optional(string)
        })))
        global_bfd = optional(object({
          profile = optional(string)
        }))
        graceful_restart = optional(object({
          enable                    = optional(bool)
          grace_period              = optional(number)
          helper_enable             = optional(bool)
          max_neighbor_restart_time = optional(number)
          strict_l_s_a_checking     = optional(bool)
        }))
        reject_default_route = optional(bool)
        router_id            = optional(string)
        timers = optional(object({
          lsa_interval          = optional(number)
          spf_calculation_delay = optional(number)
        }))
      }))
      redist_profile = optional(list(object({
        action = optional(object({
          no_redist = optional(object({
          }))
          redist = optional(object({
          }))
        }))
        filter = optional(object({
          bgp = optional(object({
            community          = optional(list(string))
            extended_community = optional(list(string))
          }))
          destination = optional(list(string))
          interface   = optional(list(string))
          nexthop     = optional(list(string))
          ospf = optional(object({
            area      = optional(list(string))
            path_type = optional(list(string))
            tag       = optional(list(string))
          }))
          type = optional(list(string))
        }))
        name     = string
        priority = optional(number)
      })))
      redist_profile_ipv6 = optional(list(object({
        action = optional(object({
          no_redist = optional(object({
          }))
          redist = optional(object({
          }))
        }))
        filter = optional(object({
          bgp = optional(object({
            community          = optional(list(string))
            extended_community = optional(list(string))
          }))
          destination = optional(list(string))
          interface   = optional(list(string))
          nexthop     = optional(list(string))
          ospfv3 = optional(object({
            area      = optional(list(string))
            path_type = optional(list(string))
            tag       = optional(list(string))
          }))
          type = optional(list(string))
        }))
        name     = string
        priority = optional(number)
      })))
      rip = optional(object({
        allow_redist_default_route = optional(bool)
        auth_profile = optional(list(object({
          md5 = optional(list(object({
            key       = optional(string)
            name      = string
            preferred = optional(bool)
          })))
          name     = string
          password = optional(string)
        })))
        enable = optional(bool)
        export_rules = optional(list(object({
          metric = optional(number)
          name   = string
        })))
        global_bfd = optional(object({
          profile = optional(string)
        }))
        interfaces = optional(list(object({
          authentication = optional(string)
          bfd = optional(object({
            profile = optional(string)
          }))
          default_route = optional(object({
            advertise = optional(object({
              metric = optional(number)
            }))
            disable = optional(object({
            }))
          }))
          enable = optional(bool)
          mode   = optional(string)
          name   = string
        })))
        reject_default_route = optional(bool)
        timers = optional(object({
          delete_intervals = optional(number)
          expire_intervals = optional(number)
          interval_seconds = optional(number)
          update_intervals = optional(number)
        }))
      }))
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
