output "name_id" {
  description = "Device-group name to base64 JSON hierarchy import identifier."
  value = { for key, item in panos_device_group_parent.this : item.device_group => base64encode(jsonencode({
    device_group = item.device_group
    location     = item.location
  })) }
}
output "parents" {
  value = { for key, item in panos_device_group_parent.this : item.device_group => item.parent }
}
