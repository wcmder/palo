mock_provider "panos" {}

run "reuse_common_with_optional_specific_template" {
  command = apply
  module { source = "./tests/fixtures/layered_templates" }
  assert {
    condition = (
      length(module.common.names.templates) == 1 &&
      module.first.templates == tolist(["test-specific", "test-common"]) &&
      module.second.templates == tolist(["test-common"])
    )
    error_message = "Stacks must reuse common and preserve template priority."
  }
  assert {
    condition = (
      module.first.names.template == "test-first" &&
      module.second.names.template == "test-second" &&
      module.first.serials == ["serial-a"] &&
      module.second.serials == ["serial-b"]
    )
    error_message = "Each stack must retain its own identity and assignments."
  }
}
