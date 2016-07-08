variable "kube_master_hostname" {
  default = "kube-master"
}

resource "libvirt_volume" "k8s_master_volume" {
  name             = "k8s-master.img"
  pool             = "${var.storage_pool}"
  base_volume_name = "${var.base_volume}"
}

resource "libvirt_domain" "k8s_master" {
  name = "${var.cluster_prefix}k8s-master"

  disk {
    volume_id = "${libvirt_volume.k8s_master_volume.id}"
  }

  network_interface {
    network_id     = "${libvirt_network.backend.id}"
    hostname       = "${var.kube_master_hostname}"
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
    source      = "../bootstrap/grains/kube-master"
    destination = "/tmp/salt/grains"
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"master: salt-master\" > /tmp/salt/minion.d/minion.conf",
      "hostnamectl set-hostname ${var.kube_master_hostname}.${libvirt_network.backend.domain}",
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
}
