output "names" {
  value = {
    for key, resource in panos_tunnel_interface.this : key => resource.name
  }
}
