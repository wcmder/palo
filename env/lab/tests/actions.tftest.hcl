# Mocked plan only: no commit/push invocation and no Panorama connection.
mock_provider "panos" {}

run "push_only_assigned_spokes" {
  command = plan
  variables {
    sites = {}
    spokes = {
      unassigned = {
        policy = {
          device_group = "test-shared"
        }
        template = {
          name  = "test-unassigned-network"
          stack = "test-unassigned-stack"
          var = {
            wan_ip = {
              description = "WAN interface IPv4 address and prefix length"
              type = {
                ip_netmask = "192.0.2.2/30"
              }
            }
            lan_ip = {
              description = "LAN interface IPv4 address and prefix length"
              type = {
                ip_netmask = "198.51.100.1/24"
              }
            }
            default_gateway = {
              description = "WAN next hop for the IPv4 default route"
              type = {
                ip_netmask = "192.0.2.1"
              }
            }
          }
          interfaces = {
            wan = {
              name    = "ethernet1/1"
              comment = "WAN interface"
              layer3 = {
                ips = [{
                  name = "$wan_ip"
                }]
              }
            }
            lan = {
              name    = "ethernet1/2"
              comment = "LAN interface"
              layer3 = {
                ips = [{
                  name = "$lan_ip"
                }]
              }
            }
          }
          zones = {
            wan = {
              name = "wan"
              network = {
                layer3 = ["ethernet1/1"]
              }
            }
            lan = {
              name = "lan"
              network = {
                layer3 = ["ethernet1/2"]
              }
            }
          }
          routers = {
            spoke = {
              name       = "spoke-vr"
              interfaces = ["ethernet1/1", "ethernet1/2"]
            }
          }
          routes = {
            default = {
              virtual_router = "spoke-vr"
              destination    = "0.0.0.0/0"
              interface      = "ethernet1/1"
              metric         = 10
              nexthop = {
                ip_address = "$default_gateway"
              }
              route_table = {
                unicast = {}
              }
            }
          }
        }
      }
      assigned = {
        policy = {
          device_group = "test-shared"
        }
        template = {
          name  = "test-assigned-network"
          stack = "test-assigned-stack"
          var = {
            wan_ip = {
              description = "WAN interface IPv4 address and prefix length"
              type = {
                ip_netmask = "192.0.2.6/30"
              }
            }
            lan_ip = {
              description = "LAN interface IPv4 address and prefix length"
              type = {
                ip_netmask = "203.0.113.1/24"
              }
            }
            default_gateway = {
              description = "WAN next hop for the IPv4 default route"
              type = {
                ip_netmask = "192.0.2.5"
              }
            }
          }
          interfaces = {
            wan = {
              name    = "ethernet1/1"
              comment = "WAN interface"
              layer3 = {
                ips = [{
                  name = "$wan_ip"
                }]
              }
            }
            lan = {
              name    = "ethernet1/2"
              comment = "LAN interface"
              layer3 = {
                ips = [{
                  name = "$lan_ip"
                }]
              }
            }
          }
          zones = {
            wan = {
              name = "wan"
              network = {
                layer3 = ["ethernet1/1"]
              }
            }
            lan = {
              name = "lan"
              network = {
                layer3 = ["ethernet1/2"]
              }
            }
          }
          routers = {
            spoke = {
              name       = "spoke-vr"
              interfaces = ["ethernet1/1", "ethernet1/2"]
            }
          }
          routes = {
            default = {
              virtual_router = "spoke-vr"
              destination    = "0.0.0.0/0"
              interface      = "ethernet1/1"
              metric         = 10
              nexthop = {
                ip_address = "$default_gateway"
              }
              route_table = {
                unicast = {}
              }
            }
          }
        }
        serials = ["test-serial-01", "test-serial-02"]
      }
    }
  }
  assert {
    condition     = keys(module.deployment.name_id.commit) == ["assigned", "unassigned"] && module.deployment.name_id.commit.assigned == "action.panos_commit.this[\"assigned\"]"
    error_message = "Every target must expose a correctly indexed commit invocation address."
  }
  assert {
    condition     = keys(module.deployment.name_id.push) == ["assigned"]
    error_message = "Unassigned spokes must not expose a push action."
  }
  assert {
    condition     = keys(module.deployment.name_id.commit_and_push) == ["assigned"] && module.deployment.name_id.commit_and_push.assigned == "action.panos_commit.commit_and_push[\"assigned\"]"
    error_message = "Combined actions must target assigned spokes only and expose their invocation addresses."
  }
  assert {
    condition     = module.deployment.push_targets.assigned.serials == tolist(["test-serial-01", "test-serial-02"])
    error_message = "Push targets must retain the explicitly assigned serials."
  }
}

run "reject_blank_serial" {
  command = plan
  variables {
    sites = {}
    spokes = {
      invalid = {
        policy = {
          device_group = "test-invalid"
        }
        template = {
          name  = "test-invalid-network"
          stack = "test-invalid-stack"
          var = {
            wan_ip = {
              description = "WAN interface IPv4 address and prefix length"
              type = {
                ip_netmask = "192.0.2.2/30"
              }
            }
            lan_ip = {
              description = "LAN interface IPv4 address and prefix length"
              type = {
                ip_netmask = "198.51.100.1/24"
              }
            }
            default_gateway = {
              description = "WAN next hop for the IPv4 default route"
              type = {
                ip_netmask = "192.0.2.1"
              }
            }
          }
          interfaces = {
            wan = {
              name    = "ethernet1/1"
              comment = "WAN interface"
              layer3 = {
                ips = [{
                  name = "$wan_ip"
                }]
              }
            }
            lan = {
              name    = "ethernet1/2"
              comment = "LAN interface"
              layer3 = {
                ips = [{
                  name = "$lan_ip"
                }]
              }
            }
          }
          zones = {
            wan = {
              name = "wan"
              network = {
                layer3 = ["ethernet1/1"]
              }
            }
            lan = {
              name = "lan"
              network = {
                layer3 = ["ethernet1/2"]
              }
            }
          }
          routers = {
            spoke = {
              name       = "spoke-vr"
              interfaces = ["ethernet1/1", "ethernet1/2"]
            }
          }
          routes = {
            default = {
              virtual_router = "spoke-vr"
              destination    = "0.0.0.0/0"
              interface      = "ethernet1/1"
              metric         = 10
              nexthop = {
                ip_address = "$default_gateway"
              }
              route_table = {
                unicast = {}
              }
            }
          }
        }
        serials = [""]
      }
    }
  }
  expect_failures = [var.spokes]
}
