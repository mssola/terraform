variable "libvirt_uri" {
  default     = "qemu:///system"
  description = "The libvirt instance"
}

variable "cluster_prefix" {
  default     = ""
  description = "Use it to avoid clashes on the same libvirt instance - use something like 'flavio-'"
}

variable "etcd_cluster_size" {
  default     = "3"
  description = "Size of the etcd cluster. Enter 3+ to have something production ready"
}

variable "kube_minions_size" {
  default     = "3"
  description = "Number of kubernetes minions to create"
}

variable "storage_pool" {
  default     = "personal"
  description = "The libvirt storage pool"
}

variable "base_volume" {
  default     = "openSUSE-Leap-btrfs.qcow2"
  description = "The base volume to use"
}
