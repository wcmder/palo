resource "panos_interface_management_profile" "this" {
  for_each                   = var.items
  name                       = each.value.name
  location                   = each.value.location
  permitted_ips              = each.value.permitted_ips
  http                       = each.value.http
  http_ocsp                  = each.value.http_ocsp
  https                      = each.value.https
  ping                       = each.value.ping
  response_pages             = each.value.response_pages
  snmp                       = each.value.snmp
  ssh                        = each.value.ssh
  telnet                     = each.value.telnet
  userid_service             = each.value.userid_service
  userid_syslog_listener_ssl = each.value.userid_syslog_listener_ssl
  userid_syslog_listener_udp = each.value.userid_syslog_listener_udp
}
