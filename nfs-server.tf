# volumes are horribly broken on cloud.suse.de ATM
#resource "openstack_blockstorage_volume_v1" "kube_nfs_volume" {
#  description = "Volume used by k8s NFS server"
#  size = 15
#}

resource "openstack_compute_instance_v2" "kube_nfs" {
  name = "${var.cluster_prefix}kube-nfs-storage"
  image_name = "openSUSE-Leap-42.1-OpenStack"
  flavor_name = "m1.small"
  key_pair = "docker"

  network = {
    name = "fixed"
  }

  #volume = {
  #  volume_id = "${openstack_blockstorage_volume_v1.kube_nfs_volume.name}"
  #}

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
    source = "bootstrap/grains/nfs"
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
