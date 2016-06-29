resource "libvirt_network" "backend" {
  name      = "k8snet"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = ["10.17.3.0/24"]
}
