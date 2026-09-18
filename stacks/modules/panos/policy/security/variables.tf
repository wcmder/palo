variable "items" {
  description = "Resources keyed by stable logical keys. Each item supplies its own location."
  type = map(object({
    location = object({
      device_group = optional(object({
        name            = optional(string)
        panorama_device = optional(string)
        rulebase        = optional(string)
      }))
      shared = optional(object({
        rulebase = optional(string)
      }))
      vsys = optional(object({
        name        = optional(string)
        ngfw_device = optional(string)
      }))
    })
    rules = list(object({
      action                             = optional(string)
      applications                       = optional(set(string))
      audit_comment_version              = optional(string)
      audit_comment_wo                   = optional(string)
      category                           = optional(list(string))
      description                        = optional(string)
      destination_addresses              = optional(set(string))
      destination_hip                    = optional(list(string))
      destination_zones                  = optional(set(string))
      disable_inspect                    = optional(bool)
      disable_server_response_inspection = optional(bool)
      disabled                           = optional(bool)
      group_tag                          = optional(string)
      icmp_unreachable                   = optional(bool)
      log_end                            = optional(bool)
      log_setting                        = optional(string)
      log_start                          = optional(bool)
      name                               = string
      negate_destination                 = optional(bool)
      negate_source                      = optional(bool)
      profile_setting = optional(object({
        group = optional(list(string))
        profiles = optional(object({
          data_filtering    = optional(list(string))
          file_blocking     = optional(list(string))
          gtp               = optional(list(string))
          sctp              = optional(list(string))
          spyware           = optional(list(string))
          url_filtering     = optional(list(string))
          virus             = optional(list(string))
          vulnerability     = optional(list(string))
          wildfire_analysis = optional(list(string))
        }))
      }))
      qos = optional(object({
        marking = optional(object({
          follow_c2s_flow = optional(object({
          }))
          ip_dscp       = optional(string)
          ip_precedence = optional(string)
        }))
      }))
      rule_type        = optional(string)
      schedule         = optional(string)
      services         = optional(set(string))
      source_addresses = optional(set(string))
      source_hip       = optional(list(string))
      source_imei      = optional(list(string))
      source_imsi      = optional(list(string))
      source_nw_slice  = optional(list(string))
      source_users     = optional(set(string))
      source_zones     = optional(set(string))
      tag              = optional(list(string))
      target = optional(object({
        devices = optional(list(object({
          name = string
          vsys = optional(list(object({
            name = string
          })))
        })))
        negate = optional(bool)
        tags   = optional(list(string))
      }))
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for item in values(var.items) : length([for scope, value in item.location : scope if value != null]) == 1])
    error_message = "Each item must set exactly one location scope."
  }

  validation {
    condition     = alltrue([for item in values(var.items) : length(distinct([for rule in item.rules : rule.name])) == length(item.rules)])
    error_message = "Rule names must be unique within each policy."
  }
  validation {
    condition     = length(distinct([for item in values(var.items) : jsonencode(item.location)])) == length(var.items)
    error_message = "Each policy item must own a different location."
  }
}
