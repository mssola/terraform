# the provider
provider = "libvirt"

# Use it to avoid clashes on the same libvirt instance - use something like '<USER>-k8s'"
# note: this should not start/end with non-alpha characters
cluster_prefix = ""

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

# the base volume in the pool
base_volume = "openSUSE-Leap-btrfs.qcow2"

# the storage pool
storage_pool = "default"

# is the image an UEFI image? then you need a valid firmware
is_uefi_image = no
firmware = "/usr/share/qemu/ovmf-x86_64-code.bin"
