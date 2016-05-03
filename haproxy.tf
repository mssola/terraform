resource "openstack_compute_floatingip_v2" "fip_kube_haproxy" {
  pool = "floating"
}

output "kube-haproxy-fip" {
  value = "${openstack_compute_floatingip_v2.fip_kube_haproxy.address}"
}

resource "openstack_compute_instance_v2" "kube-haproxy" {
  name = "${var.cluster-prefix}kube-haproxy"
  image_name = "openSUSE-Leap-42.1-OpenStack"
  flavor_name = "m1.small"
  key_pair = "docker"

  network = {
    name = "fixed"
    floating_ip = "${openstack_compute_floatingip_v2.fip_kube_haproxy.address}"
    access_network = "true"
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
    source = "bootstrap/grains/haproxy"
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
