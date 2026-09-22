module "common" {
  source = "../../../../../stacks/dev/templates/shared/common"
  item = {
    name        = "test-common"
    description = "Shared device settings"
  }
}

module "specific" {
  source = "../../../../../stacks/modules/panos/panorama/template"
  items = {
    template = {
      name        = "test-specific"
      description = "Stack-specific settings"
      location    = { panorama = {} }
    }
  }
}

module "first" {
  source = "../../../../../stacks/dev/templates/spoke/stacks"
  item = {
    name        = "test-first"
    description = "Common plus specific"
    templates = [
      module.specific.names.template,
      module.common.names.template
    ]
    serials = ["serial-a"]
  }
}

module "second" {
  source = "../../../../../stacks/dev/templates/spoke/stacks"
  item = {
    name        = "test-second"
    description = "Common only"
    templates   = [module.common.names.template]
    serials     = ["serial-b"]
  }
}
