provider "libvirt" {
  uri = "${var.libvirt_uri}"
}

resource "libvirt_volume" "salt_volume" {
  name             = "salt-k8s.img"
  pool             = "${var.storage_pool}"
  base_volume_name = "${var.base_volume}"
}

resource "libvirt_domain" "salt" {
  name = "${var.cluster_prefix}k8s-salt"

  disk {
    volume_id = "${libvirt_volume.salt_volume.id}"
  }

  network_interface {
    network_id     = "${libvirt_network.backend.id}"
    hostname       = "salt-master"
    wait_for_lease = 1
  }

  connection {
    user     = "root"
    password = "vagrant"
  }

  provisioner "file" {
    source      = "../bootstrap/salt"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "../salt/salt"
    destination = "/srv"
  }

  provisioner "file" {
    source      = "../salt/pillar"
    destination = "/srv"
  }

  provisioner "remote-exec" {
    inline = [
      "hostnamectl set-hostname ${libvirt_domain.salt.network_interface.0.hostname}.${libvirt_network.backend.domain}",
      "bash /tmp/salt/provision-salt-master.sh",
    ]
  }
}

output "salt-ip" {
  value = "${libvirt_domain.salt.network_interface.0.addresses.0}"
}
