variable "items" {
  description = "Zone protection profiles keyed by stable logical keys; each supplies name and location plus provider settings."
  type        = any
  default     = {}
}
