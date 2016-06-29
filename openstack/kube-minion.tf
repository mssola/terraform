resource "openstack_compute_instance_v2" "kube-minion" {
  name = "${var.cluster_prefix}kube-minion${count.index}"
  image_name = "${var.openstack_image}"
  flavor_name = "m1.small"
  key_pair = "docker"
  count = "${var.kube_minions_size}"

  network = {
    name = "fixed"
  }
  depends_on = ["openstack_compute_instance_v2.salt"]

  provisioner "file" {
    source = "bootstrap/salt"
    destination = "/tmp"
    connection {
      private_key = "${file("ssh/id_docker")}"
      bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
    }
  }
  provisioner "file" {
    source = "bootstrap/grains/kube-minion"
    destination = "/tmp/salt/grains"
    connection {
      private_key = "${file("ssh/id_docker")}"
      bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"master: ${openstack_compute_instance_v2.salt.network.0.fixed_ip_v4}\" > /tmp/salt/minion.d/minion.conf "
    ]
    connection {
      private_key = "${file("ssh/id_docker")}"
      bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "bash /tmp/salt/provision-salt-minion.sh"
    ]
    connection {
      private_key = "${file("ssh/id_docker")}"
      bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
    }
  }
}
