resource "openstack_compute_floatingip_v2" "fip_kube_haproxy" {
  pool = "floating"
}

output "kube-haproxy-fip" {
  value = "${openstack_compute_floatingip_v2.fip_kube_haproxy.address}"
}

resource "openstack_compute_instance_v2" "kube-haproxy" {
  name        = "${var.cluster_prefix}kube-haproxy"
  image_name  = "${var.openstack_image}"
  flavor_name = "m1.small"
  key_pair    = "${var.key_pair}"

  network = {
    name           = "fixed"
    floating_ip    = "${openstack_compute_floatingip_v2.fip_kube_haproxy.address}"
    access_network = "true"
  }

  depends_on = ["openstack_compute_instance_v2.salt"]

  connection {
    private_key  = "${file("${var.private_key}")}"
    bastion_host = "${openstack_compute_floatingip_v2.fip_salt.address}"
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
      "echo \"master: ${openstack_compute_instance_v2.salt.network.0.fixed_ip_v4}\" > /tmp/salt/minion.d/minion.conf ",
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
}
