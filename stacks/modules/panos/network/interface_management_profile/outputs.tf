output "names" {
  description = "Logical role to profile name."
  value = {
    for key, p in panos_interface_management_profile.this : key => p.name
  }
}

output "name_id" {
  description = "Profile name to import identifier."
  value = {
    for key, p in panos_interface_management_profile.this :
    p.name => base64encode(jsonencode({
      name = p.name
      location = { for scope, config in p.location : scope => {
        for attribute, value in config : attribute => value if value != null
      } if config != null }
    }))
  }
}

output "settings" {
  description = "Management services and permitted sources by role."
  value = {
    for key, p in panos_interface_management_profile.this : key => {
      http                       = p.http
      http_ocsp                  = p.http_ocsp
      https                      = p.https
      ping                       = p.ping
      response_pages             = p.response_pages
      snmp                       = p.snmp
      ssh                        = p.ssh
      telnet                     = p.telnet
      userid_service             = p.userid_service
      userid_syslog_listener_ssl = p.userid_syslog_listener_ssl
      userid_syslog_listener_udp = p.userid_syslog_listener_udp
      permitted_ips              = p.permitted_ips
    }
  }
}
