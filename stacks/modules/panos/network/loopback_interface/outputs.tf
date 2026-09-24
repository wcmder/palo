output "names" {
  description = "Logical input key to loopback interface name."
  value = {
    for key, resource in panos_loopback_interface.this : key => resource.name
  }
}
