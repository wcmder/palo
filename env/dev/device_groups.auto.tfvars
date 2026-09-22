# Policy membership is independent of network template-stack membership.
device_groups = {
  parent = {
    device_group = "parent"
    serials      = []
  }
  spoke = {
    device_group = "spoke"
    parent       = "parent"
    serials      = ["007954000920842", "007954000920860"]
  }
  hub = {
    device_group = "hub"
    parent       = "parent"
    serials      = ["007954000920861"]
  }
}
