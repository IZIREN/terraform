variable "cluster_prefix" {
  default = ""
  description = "use it to avoid clashes on the same openstack instance - use something like 'flavio-'"

}

variable "etcd_cluster_size" {
  default = "3"
  description = "Size of the etcd cluster. Enter 3+ to have something production ready"
}

variable "kube_minions_size" {
  default = "3"
  description = "Number of kubernetes minions to create"
}
