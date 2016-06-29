resource "openstack_compute_floatingip_v2" "fip_salt" {
  pool = "floating"
}

output "salt-fip" {
  value = "${openstack_compute_floatingip_v2.fip_salt.address}"
}

resource "openstack_compute_instance_v2" "salt" {
  name        = "${var.cluster_prefix}kube-salt"
  image_name  = "${var.openstack_image}"
  flavor_name = "m1.small"
  key_pair    = "${var.key_pair}"

  network = {
    name           = "fixed"
    floating_ip    = "${openstack_compute_floatingip_v2.fip_salt.address}"
    access_network = "true"
  }

  connection {
    private_key = "${file("${var.private_key}")}"
  }

  provisioner "file" {
    source      = "../ssh/id_docker"
    destination = "/root/.ssh/id_rsa"
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
      "mkdir -p /etc/salt/master.d",
    ]
  }

  provisioner "file" {
    source      = "../salt/salt-conf/"
    destination = "/etc/salt/master.d"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/id_rsa",
      "bash /tmp/salt/provision-salt-master.sh",
    ]
  }
}
