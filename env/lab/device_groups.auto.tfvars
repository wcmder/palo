# Policy membership is independent of network template-stack membership.
device_groups = {
  parent = {
    serials = []
  }
  spoke = {
    parent  = "parent"
    serials = ["007954000920842"]
  }
}
