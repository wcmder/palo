output "names" {
  value = {
    for key, resource in panos_gre_tunnel.this : key => resource.name
  }
}

output "endpoints" {
  value = { for key, tunnel in panos_gre_tunnel.this : key => {
    location         = tunnel.location
    local_address    = tunnel.local_address
    peer_address     = tunnel.peer_address
    tunnel_interface = tunnel.tunnel_interface
  } }
}
