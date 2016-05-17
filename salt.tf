resource "openstack_compute_floatingip_v2" "fip_salt" {
  pool = "floating"
}

output "salt-fip" {
  value = "${openstack_compute_floatingip_v2.fip_salt.address}"
}

resource "openstack_compute_instance_v2" "salt" {
  name = "${var.cluster-prefix}kube-salt"
  image_name = "openSUSE-Leap-42.1-OpenStack"
  flavor_name = "m1.small"
  key_pair = "docker"
  network = {
    name = "fixed"
    floating_ip = "${openstack_compute_floatingip_v2.fip_salt.address}"
    access_network = "true"
  }
  provisioner "file" {
    source = "ssh/id_docker"
    destination = "/root/.ssh/id_rsa"
    connection {
      private_key = "${file("ssh/id_docker")}"
    }
  }
  provisioner "file" {
    source = "bootstrap/salt"
    destination = "/tmp"
    connection {
      private_key = "${file("ssh/id_docker")}"
    }
  }
  provisioner "file" {
    source = "salt"
    destination = "/srv"
    connection {
      private_key = "${file("ssh/id_docker")}"
    }
  }
  provisioner "file" {
    source = "pillar"
    destination = "/srv"
    connection {
      private_key = "${file("ssh/id_docker")}"
    }
  }
  provisioner "file" {
    source = "salt-conf"
    destination = "/etc/salt/master.d"
    connection {
      private_key = "${file("ssh/id_docker")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/id_rsa"
    ]
    connection {
      private_key = "${file("ssh/id_docker")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "bash /tmp/salt/provision-salt-master.sh"
    ]
    connection {
      private_key = "${file("ssh/id_docker")}"
    }
  }
}
