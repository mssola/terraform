resource "openstack_compute_instance_v2" "etcd" {
  name        = "${var.cluster_prefix}etcd${count.index}"
  image_name  = "${var.openstack_image}"
  flavor_name = "m1.small"
  key_pair    = "${var.key_pair}"
  count       = "${var.etcd_cluster_size}"

  network = {
    name = "fixed"
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
    source      = "../bootstrap/grains/etcd"
    destination = "/tmp/salt/grains"
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"master: ${openstack_compute_instance_v2.salt.network.0.fixed_ip_v4}\" > /tmp/salt/minion.d/minion.conf ",
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
}
