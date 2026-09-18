output "name_id" {
  value = {
    services = { for key, instance in module.services : key => instance.name_id }
    nat      = module.nat.name_id
    security = module.security.name_id
  }
}
