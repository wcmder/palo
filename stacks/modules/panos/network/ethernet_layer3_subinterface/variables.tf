variable "items" {
  description = "Layer 3 subinterfaces keyed by stable logical keys."
  type = map(object({
    name   = string
    parent = string
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
    interface_management_profile = optional(string)
    tag                          = number
    comment                      = optional(string)
    ip = optional(list(object({
      name          = string
      sdwan_gateway = optional(string)
    })))
  }))
  default = {}

  validation {
    condition = length(distinct([
      for item in values(var.items) : item.name
    ])) == length(var.items)
    error_message = "Subinterface names must be unique within a module call."
  }
}
