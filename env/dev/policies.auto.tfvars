# Common policy settings are independent of network template settings.
policies = {
  common = {
    device_group  = "parent"
    mgmt_zone     = "mgmt"
    gre_endpoints = ["10.0.1.2", "10.0.2.2", "10.0.3.2"]
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
