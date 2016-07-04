resource "libvirt_volume" "k8s_nfs_volume" {
  name             = "k8s-nfs.img"
  pool             = "${var.storage_pool}"
  base_volume_name = "${var.base_volume}"
}

resource "libvirt_domain" "k8s_nfs" {
  name = "${var.cluster_prefix}k8s-nfs"

  disk {
    volume_id = "${libvirt_volume.k8s_nfs_volume.id}"
  }

  network_interface {
    network_id     = "${libvirt_network.backend.id}"
    hostname       = "nfs-server"
    wait_for_lease = 1
  }

  depends_on = ["libvirt_domain.salt"]

  connection {
    user     = "root"
    password = "vagrant"
  }

  provisioner "file" {
    source      = "../bootstrap/salt"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "../bootstrap/grains/nfs"
    destination = "/tmp/salt/grains"
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"master: salt-master\" > /tmp/salt/minion.d/minion.conf",
      "hostnamectl set-hostname ${libvirt_domain.k8s_nfs.network_interface.0.hostname}.${libvirt_network.backend.domain}",
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
}
