mock_provider "panos" {}

run "multiple_resources_and_names" {
  command = apply
  module { source = "./tests/fixtures/all" }
  assert {
    condition     = length(output.device_group) == 2
    error_message = "device_group must output two names."
  }
  assert {
    condition     = output.device_group["item0"] == "example-0"
    error_message = "device_group names output must preserve the resource name."
  }
  assert {
    condition     = length(output.template) == 2
    error_message = "template must output two names."
  }
  assert {
    condition     = output.template["item0"] == "example-0"
    error_message = "template names output must preserve the resource name."
  }
  assert {
    condition     = length(output.template_stack) == 2
    error_message = "template_stack must output two names."
  }
  assert {
    condition     = output.template_stack["item0"] == "example-0"
    error_message = "template_stack names output must preserve the resource name."
  }
  assert {
    condition     = length(output.address) == 2
    error_message = "address must output two names."
  }
  assert {
    condition     = output.address["item0"] == "example-0"
    error_message = "address names output must preserve the resource name."
  }
  assert {
    condition     = length(output.address_group) == 2
    error_message = "address_group must output two names."
  }
  assert {
    condition     = output.address_group["item0"] == "example-0"
    error_message = "address_group names output must preserve the resource name."
  }
  assert {
    condition     = length(output.service) == 2
    error_message = "service must output two names."
  }
  assert {
    condition     = output.service["item0"] == "example-0"
    error_message = "service names output must preserve the resource name."
  }
  assert {
    condition     = length(output.service_group) == 2
    error_message = "service_group must output two names."
  }
  assert {
    condition     = output.service_group["item0"] == "example-0"
    error_message = "service_group names output must preserve the resource name."
  }
  assert {
    condition     = length(output.administrative_tag) == 2
    error_message = "administrative_tag must output two names."
  }
  assert {
    condition     = output.administrative_tag["item0"] == "example-0"
    error_message = "administrative_tag names output must preserve the resource name."
  }
  assert {
    condition     = length(output.ethernet_interface) == 2
    error_message = "ethernet_interface must output two names."
  }
  assert {
    condition     = output.ethernet_interface["item0"] == "ethernet1/1"
    error_message = "ethernet_interface names output must preserve the resource name."
  }
  assert {
    condition     = length(output.zone) == 2
    error_message = "zone must output two names."
  }
  assert {
    condition     = output.zone["item0"] == "example-0"
    error_message = "zone names output must preserve the resource name."
  }
  assert {
    condition     = length(output.virtual_router) == 2
    error_message = "virtual_router must output two names."
  }
  assert {
    condition     = output.virtual_router["item0"] == "example-0"
    error_message = "virtual_router names output must preserve the resource name."
  }
  assert {
    condition     = length(output.security_policy) == 2
    error_message = "security_policy must output two names."
  }
  assert {
    condition     = output.security_policy["item0"] == ["first", "second"]
    error_message = "security_policy names output must preserve rule ordering."
  }
  assert {
    condition     = length(output.nat_policy) == 2
    error_message = "nat_policy must output two names."
  }
  assert {
    condition     = output.nat_policy["item0"] == ["first", "second"]
    error_message = "nat_policy names output must preserve rule ordering."
  }
}
