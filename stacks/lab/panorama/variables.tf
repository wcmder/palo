variable "sites" {
  description = "Sites keyed by stable site identifiers. Empty by default."
  type = map(object({
    device_group   = string
    template       = string
    template_stack = string
    description    = optional(string)
    serials        = optional(list(string), [])
    addresses      = optional(map(string), {})
  }))
  default = {}
}
