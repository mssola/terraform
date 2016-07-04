resource "libvirt_volume" "k8s_etcd_volume" {
  name             = "k8s-etcd${count.index}.img"
  pool             = "${var.storage_pool}"
  base_volume_name = "${var.base_volume}"
  count            = "${var.etcd_cluster_size}"
}

resource "libvirt_domain" "k8s_etcd" {
  count = "${var.etcd_cluster_size}"
  name  = "${var.cluster_prefix}k8s-etcd${count.index}"

  disk {
    volume_id = "${element(libvirt_volume.k8s_etcd_volume.*.id, count.index)}"
  }

  network_interface {
    network_id     = "${libvirt_network.backend.id}"
    hostname       = "etcd${count.index}"
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
    source      = "../bootstrap/grains/etcd"
    destination = "/tmp/salt/grains"
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"master: salt-master\" > /tmp/salt/minion.d/minion.conf",
      "hostnamectl set-hostname ${libvirt_domain.k8s_etcd.network_interface.0.hostname}.${libvirt_network.backend.domain}",
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
}
