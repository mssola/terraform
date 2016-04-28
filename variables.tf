variable "cluster-prefix" {
  default = ""
  description = "use it to avoid clashes on the same openstack instance - use something like 'flavio-'"

}

variable "etcd-cluster-size" {
  default = "3"
  description = "Size of the etcd cluster. Enter 3+ to have something production ready"
}

variable "kube-minions-size" {
  default = "3"
  description = "Number of kubernetes minions to create"
}
