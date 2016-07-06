variable "kube_minion_base_hostname" {
  default = "minion"
}

resource "libvirt_volume" "k8s_minion_volume" {
  name             = "k8s-minion${count.index}.img"
  pool             = "${var.storage_pool}"
  base_volume_name = "${var.base_volume}"
  count            = "${var.kube_minions_size}"
}

resource "libvirt_domain" "k8s_minion" {
  count = "${var.kube_minions_size}"
  name  = "${var.cluster_prefix}k8s-minion${count.index}"

  disk {
    volume_id = "${element(libvirt_volume.k8s_minion_volume.*.id, count.index)}"
  }

  network_interface {
    network_id     = "${libvirt_network.backend.id}"
    hostname       = "${var.kube_minion_base_hostname}${count.index}"
    wait_for_lease = 1
  }

  depends_on = ["libvirt_domain.salt", "libvirt_domain.k8s_master", "libvirt_domain.k8s_nfs"]

  connection {
    user     = "root"
    password = "vagrant"
  }

  provisioner "file" {
    source      = "../bootstrap/salt"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "../bootstrap/grains/kube-minion"
    destination = "/tmp/salt/grains"
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"master: salt-master\" > /tmp/salt/minion.d/minion.conf ",
      "hostnamectl set-hostname ${var.kube_minion_base_hostname}${count.index}.${libvirt_network.backend.domain}",
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
}
