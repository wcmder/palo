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
  description = "Required spoke template object passed to the explicit stack call."
  type        = any
  nullable    = false
  validation {
    condition     = alltrue([for key in keys(var.templates) : key == "spoke"])
    error_message = "This root declares only spoke. Add an explicit root stack call before introducing another role."
  }
  validation {
    condition = alltrue([for field in ["name", "stack"] :
      length(distinct([for item in values(var.templates) : item[field]])) == length(var.templates)
    ])
    error_message = "Each template must have a unique name and stack."
  }
  validation {
    condition     = length(distinct(flatten([for item in values(var.templates) : item.serials]))) == length(flatten([for item in values(var.templates) : item.serials]))
    error_message = "A firewall can belong to only one template stack."
  }
  validation {
    condition = alltrue(flatten([for item in values(var.templates) : [for serial in item.serials :
      trimspace(serial) != "" && serial == trimspace(serial)
    ]]))
    error_message = "Template serials must be non-empty and have no surrounding whitespace."
  }
}

variable "policies" {
  description = "Policy inputs by family. common is one object with device_group and network settings; all fields consumed by the stack must be supplied."
  type        = any
  nullable    = false
}
