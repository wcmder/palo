# Common policy settings are independent of network template settings.
policies = {
  common = {
    device_group  = "parent"
    lan_zone      = "lan"
    wan_zone      = "wan"
    wan_interface = "ethernet1/1"
    # Block unmatched same-zone traffic; earlier explicit allows still apply.
    default_security_rules = [{
      name    = "intrazone-default"
      action  = "deny"
      log_end = true
    }]
  }
}
