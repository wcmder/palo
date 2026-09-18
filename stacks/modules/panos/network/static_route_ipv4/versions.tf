terraform {
  required_version = ">= 1.8.0"
  required_providers {
    panos = {
      source  = "PaloAltoNetworks/panos"
      version = ">= 2.0.13, < 3.0.0"
    }
  }
}
