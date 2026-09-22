variable "device_groups" {
  description = "Device groups keyed by Panorama name. parent=null means Shared; serials assign firewalls independently of templates. Supports one parent tier and child groups."
  type        = any
  default     = {}
  validation {
    condition = alltrue([for name, group in var.device_groups :
      try(group.parent, null) == null ? true : try(
        group.parent != name &&
        contains(keys(var.device_groups), group.parent) &&
        try(var.device_groups[group.parent].parent, null) == null,
        false
      )
    ])
    error_message = "Each parent must reference a different declared group whose parent is omitted or null. Use one parent tier plus child groups."
  }
}

variable "templates" {
  description = "Shared template definitions, independent of stack membership."
  type        = any
  nullable    = false
  validation {
    condition = length(distinct([
      for item in values(var.templates) : item.name
    ])) == length(var.templates)
    error_message = "Shared template names must be unique."
  }
}

variable "template_stacks" {
  description = "Stack definitions with ordered template keys and serials."
  type        = any
  nullable    = false
  validation {
    condition = length(distinct([
      for item in values(var.template_stacks) : item.name
    ])) == length(var.template_stacks)
    error_message = "Template stack names must be unique."
  }
  validation {
    condition = length(distinct(flatten([
      for item in values(var.template_stacks) : item.serials
      ]))) == length(flatten([
      for item in values(var.template_stacks) : item.serials
    ]))
    error_message = "A firewall can belong to only one template stack."
  }
  validation {
    condition = alltrue(flatten([
      for item in values(var.template_stacks) : [for serial in item.serials :
        trimspace(serial) != "" && serial == trimspace(serial)
      ]
    ]))
    error_message = "Stack serials must be non-empty with no surrounding space."
  }
  validation {
    condition = alltrue(flatten([
      for item in values(var.template_stacks) : [for key in item.templates :
        contains(keys(var.templates), key)
      ]
    ]))
    error_message = "Every stack template key must reference a defined template."
  }
}

variable "policies" {
  description = "Policy inputs by family. common is one object with device_group and network settings; all fields consumed by the stack must be supplied."
  type        = any
  nullable    = false
}
