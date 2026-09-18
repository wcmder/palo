mock_provider "panos" {}

run "multiple_variables_and_routes" {
  command = apply
  module { source = "./tests/fixtures/all" }
  assert {
    condition     = length(output.template_variable) == 2 && length(output.static_route_ipv4) == 2
    error_message = "Both new feature modules must create multiple resources."
  }
  assert {
    condition     = jsondecode(base64decode(output.static_route_ipv4["default"])).virtual_router == "example-vr"
    error_message = "Route import identities must include their parent virtual router."
  }
  assert {
    condition     = jsondecode(base64decode(output.template_variable["$wan_ip"])).location.template.name == "example-template"
    error_message = "Template variable identity must retain its template scope."
  }
}

run "two_spokes" {
  command = apply
  module { source = "../../stacks/lab/spoke" }
  variables {
    items = {
      spoke01 = {
        policy = {
          device_group = "test-shared-spoke"
        }
        template = {
          name  = "test-spoke01-network"
          stack = "test-spoke01-stack"
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
        serials = ["test-serial-01"]
      }
      spoke02 = {
        policy = {
          device_group = "test-shared-spoke"
        }
        template = {
          name  = "test-spoke02-network"
          stack = "test-spoke02-stack"
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
                ip_netmask = "203.0.113.1/25"
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
              name    = "ethernet1/3"
              comment = "WAN interface"
              layer3 = {
                ips = [{
                  name = "$wan_ip"
                }]
              }
            }
            lan = {
              name    = "ethernet1/4"
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
                layer3 = ["ethernet1/3"]
              }
            }
            lan = {
              name = "lan"
              network = {
                layer3 = ["ethernet1/4"]
              }
            }
          }
          routers = {
            spoke = {
              name       = "spoke-vr"
              interfaces = ["ethernet1/3", "ethernet1/4"]
            }
          }
          routes = {
            default = {
              virtual_router = "spoke-vr"
              destination    = "0.0.0.0/0"
              interface      = "ethernet1/3"
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
        serials = ["test-serial-02"]
      }
    }
  }
  assert {
    condition     = length(output.name_id.device_groups) == 1 && length(output.name_id.interfaces.spoke01) == 2 && length(output.name_id.variables.spoke02) == 3
    error_message = "Spokes must share one device group while retaining separate templates, interfaces and variables."
  }
  assert {
    condition     = toset(output.device_group_memberships["test-shared-spoke"]) == toset(["test-serial-01", "test-serial-02"])
    error_message = "The shared group must retain both spokes' serials."
  }
  assert {
    condition     = module.template.variable_values["spoke01"]["$wan_ip"] == "192.0.2.2/30" && module.template.variable_values["spoke02"]["$lan_ip"] == "203.0.113.1/25"
    error_message = "Native template variables must retain the host IP and supplied prefix."
  }
  assert {
    condition     = module.template.variable_values["spoke02"]["$default_gateway"] == "192.0.2.5" && output.names.interfaces.spoke02.wan == "ethernet1/3"
    error_message = "The second spoke must use its own gateway and interface name."
  }
  assert {
    condition     = jsondecode(base64decode(output.name_id.routes.spoke02["default"])).location.template.name == "test-spoke02-network"
    error_message = "The default route must be scoped to the correct spoke template."
  }
}

run "shared_stack_unassigned_variables" {
  command = apply
  module { source = "../../stacks/lab/spoke" }
  variables {
    items = {
      shared = {
        policy = {
          device_group = "shared"
        }
        template = {
          name  = "shared-network"
          stack = "shared-stack"
          var = {
            wan_ip = {
              description = "WAN interface IPv4 address and prefix length"
              type = {
                ip_netmask = "None"
              }
            }
            lan_ip = {
              description = "LAN interface IPv4 address and prefix length"
              type = {
                ip_netmask = "None"
              }
            }
            default_gateway = {
              description = "WAN next hop for the IPv4 default route"
              type = {
                ip_netmask = "None"
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
        serials = ["serial-a", "serial-b"]

      }
    }
  }
  assert {
    condition = alltrue([
      for name in ["$wan_ip", "$lan_ip", "$default_gateway"] :
      module.template.variable_values["shared"][name] == "None"
    ])
    error_message = "Unassigned variables must retain the literal Panorama None value."
  }
  assert {
    condition     = length(output.name_id.templates) == 1 && length(output.name_id.template_stacks) == 1 && length(output.device_group_memberships.shared) == 2
    error_message = "Both serials must share one template and stack."
  }
}


run "additional_dmz_configuration" {
  command = apply
  variables {
    sites = {}
    spokes = {
      branch = {
        policy = { device_group = "branch" }
        template = {
          name  = "branch-network"
          stack = "branch-stack"
          var = {
            dmz_ip = { type = { ip_netmask = "None" } }
          }
          interfaces = {
            dmz = {
              name = "ethernet1/3"
              layer3 = {
                mtu = 1400
                ips = [{ name = "$dmz_ip" }]
              }
            }
          }
          zones = {
            dmz = { network = { layer3 = ["ethernet1/3"] } }
          }
          routers = {
            edge = { name = "edge-vr", interfaces = ["ethernet1/3"] }
          }
          routes = {
            internal = {
              virtual_router = "edge-vr"
              destination    = "10.99.0.0/16"
              interface      = "ethernet1/3"
              nexthop        = { ip_address = "10.3.1.1" }
            }
          }
        }
      }
      empty = {
        policy   = { device_group = "empty" }
        template = { name = "empty-network", stack = "empty-stack" }
      }
    }
  }
  assert {
    condition     = module.spokes.names.interfaces.branch.dmz == "ethernet1/3" && module.spokes.names.variables.branch.dmz_ip == "$dmz_ip"
    error_message = "New resource and variable keys must pass through without parent schema declarations."
  }
  assert {
    condition     = length(module.spokes.name_id.zones.branch) == 1 && length(module.spokes.name_id.routes.branch) == 1 && length(module.spokes.name_id.interfaces.empty) == 0
    error_message = "Each configuration must support different maps and omitted optional maps."
  }
}

run "reject_duplicate_interface_names" {
  command = plan
  module { source = "../../stacks/lab/spoke/template" }
  variables {
    items = {
      bad = {
        name  = "bad"
        stack = "bad-stack"
        interfaces = {
          first  = { name = "ethernet1/1" }
          second = { name = "ethernet1/1" }
        }
      }
    }
  }
  expect_failures = [var.items]
}

run "reject_invalid_variable_address" {
  command = plan
  module { source = "../../stacks/lab/spoke/template" }
  variables {
    items = {
      bad = {
        name  = "bad"
        stack = "bad-stack"
        var   = { dmz_ip = { type = { ip_netmask = "10.1.1.2/99" } } }
      }
    }
  }
  expect_failures = [var.items]
}
