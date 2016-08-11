# the provider
provider = "libvirt"

# Use it to avoid clashes on the same libvirt instance - use something like '<USER>_k8s'"
# note: this should not start/end with non-alpha characters
cluster_prefix = ""

# the directory where we hold our Salt files
salt_dir = ?

#######################
# cluster sizes
#######################
etcd_cluster_size = 3
kube_minions_size = 3

#######################
# libvirt
#######################
# the libvirt instance
libvirt_uri = "qemu:///system"

# the base volume or source URL in the pool
volume_base = "openSUSE-Leap-btrfs.qcow2"
volume_source =

# the storage pool
volume_pool = "default"

# is the image an UEFI image? then you need a valid firmware
is_uefi_image = no
firmware = "/usr/share/qemu/ovmf-x86_64-code.bin"
