mock_provider "panos" {}

run "multiple_resources_and_identifiers" {
  command = apply
  module { source = "./tests/fixtures/all" }
  assert {
    condition     = length(output.device_group) == 2
    error_message = "device_group must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.device_group["example-0"])).name == "example-0"
    error_message = "device_group import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.template) == 2
    error_message = "template must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.template["example-0"])).name == "example-0"
    error_message = "template import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.template_stack) == 2
    error_message = "template_stack must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.template_stack["example-0"])).name == "example-0"
    error_message = "template_stack import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.address) == 2
    error_message = "address must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.address["example-0"])).name == "example-0"
    error_message = "address import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.address_group) == 2
    error_message = "address_group must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.address_group["example-0"])).name == "example-0"
    error_message = "address_group import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.service) == 2
    error_message = "service must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.service["example-0"])).name == "example-0"
    error_message = "service import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.service_group) == 2
    error_message = "service_group must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.service_group["example-0"])).name == "example-0"
    error_message = "service_group import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.administrative_tag) == 2
    error_message = "administrative_tag must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.administrative_tag["example-0"])).name == "example-0"
    error_message = "administrative_tag import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.ethernet_interface) == 2
    error_message = "ethernet_interface must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.ethernet_interface["ethernet1/1"])).name == "ethernet1/1"
    error_message = "ethernet_interface import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.zone) == 2
    error_message = "zone must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.zone["example-0"])).name == "example-0"
    error_message = "zone import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.virtual_router) == 2
    error_message = "virtual_router must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.virtual_router["example-0"])).name == "example-0"
    error_message = "virtual_router import identity must preserve the resource name."
  }
  assert {
    condition     = length(output.security_policy) == 2
    error_message = "security_policy must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.security_policy["item0"])).names == ["first", "second"]
    error_message = "security_policy import identity must preserve rule ordering."
  }
  assert {
    condition     = length(output.nat_policy) == 2
    error_message = "nat_policy must output two identifiers."
  }
  assert {
    condition     = jsondecode(base64decode(output.nat_policy["item0"])).names == ["first", "second"]
    error_message = "nat_policy import identity must preserve rule ordering."
  }
}

run "two_site_lab" {
  command = apply
  variables {
    sites = {
      branch01 = {
        device_group   = "lab-branch01"
        template       = "lab-branch01-network"
        template_stack = "lab-branch01-stack"
        addresses = {
          "branch01-lan"     = "192.0.2.0/25"
          "branch01-servers" = "192.0.2.128/25"
        }
      }
      branch02 = {
        device_group   = "lab-branch02"
        template       = "lab-branch02-network"
        template_stack = "lab-branch02-stack"
        addresses = {
          "branch02-lan"     = "198.51.100.0/25"
          "branch02-servers" = "198.51.100.128/25"
        }
      }
    }

  }
  assert {
    condition     = length(module.panorama.name_id.device_groups) == 2 && length(module.panorama.name_id.addresses.branch01) == 2
    error_message = "The composed lab must create both sites and their addresses."
  }
}
