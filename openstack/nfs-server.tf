# volumes are horribly broken on cloud.suse.de ATM

#resource "openstack_blockstorage_volume_v1" "kube_nfs_volume" {

#  description = "Volume used by k8s NFS server"

#  size = 15

#}

resource "openstack_compute_instance_v2" "kube_nfs" {
  name        = "${var.cluster_prefix}kube-nfs-storage"
  image_name  = "${var.openstack_image}"
  flavor_name = "m1.small"
  key_pair    = "${var.key_pair}"

  network = {
    name = "fixed"
  }

  #volume = {


  #  volume_id = "${openstack_blockstorage_volume_v1.kube_nfs_volume.name}"


  #}

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
    source      = "../bootstrap/grains/nfs"
    destination = "/tmp/salt/grains"
  }
  provisioner "remote-exec" {
    inline = [
      "echo \"master: ${openstack_compute_instance_v2.salt.network.0.fixed_ip_v4}\" > /tmp/salt/minion.d/minion.conf ",
      "bash /tmp/salt/provision-salt-minion.sh",
    ]
  }
}
