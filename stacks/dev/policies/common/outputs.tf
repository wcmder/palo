output "name_id" {
  value = {
    default_security = module.default_security.name_id
    services         = module.services.name_id
    nat              = module.nat.name_id
    security         = module.security.name_id
  }
}
