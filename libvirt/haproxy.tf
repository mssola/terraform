resource "libvirt_volume" "k8s_haproxy_volume" {
  name             = "k8s-haproxy.img"
  pool             = "${var.storage_pool}"
  base_volume_name = "${var.base_volume}"
}

resource "libvirt_domain" "k8s_haproxy" {
  name = "${var.cluster_prefix}k8s-haproxy"

  disk {
    volume_id = "${libvirt_volume.k8s_haproxy_volume.id}"
  }

  network_interface {
    network_id     = "${libvirt_network.backend.id}"
    hostname       = "haproxy"
    wait_for_lease = 1
  }

  depends_on = ["libvirt_domain.salt", "libvirt_domain.k8s_etcd"]

  connection {
    user     = "root"
    password = "vagrant"
  }

  provisioner "file" {
    source      = "../bootstrap/salt"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "../bootstrap/grains/haproxy"
    destination = "/tmp/salt/grains"
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"master: salt-master\" > /tmp/salt/minion.d/minion.conf",
      "hostnamectl set-hostname ${libvirt_domain.k8s_haproxy.network_interface.0.hostname}.${libvirt_network.backend.domain}",
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
}
