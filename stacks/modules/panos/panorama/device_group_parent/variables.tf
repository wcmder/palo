variable "items" {
  type = map(object({
    device_group = string
    parent       = optional(string, "")
    location = object({
      panorama = object({ panorama_device = optional(string, "localhost.localdomain") })
    })
  }))
  default = {}
}
