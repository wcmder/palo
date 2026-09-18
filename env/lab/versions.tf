terraform {
  required_version = ">= 1.14.0"
  required_providers {
    panos = {
      source  = "PaloAltoNetworks/panos"
      version = "= 2.0.13"
    }
  }
}
