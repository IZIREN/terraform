# Configuration variables
#
# You can override any of these variables from command line by defining `TF_VAR_<the_variable>`
# For example `TF_VAR_cluster_prefix="alvaro-" terraform apply`

variable "cluster_prefix" {
  default     = ""
  description = "use it to avoid clashes on the same openstack instance - use something like 'flavio-'"
}

variable "etcd_cluster_size" {
  default     = "3"
  description = "Size of the etcd cluster. Enter 3+ to have something production ready"
}

variable "kube_minions_size" {
  default     = "3"
  description = "Number of kubernetes minions to create"
}

variable "openstack_image" {
  default     = "openSUSE-Leap-42.1"
  description = "The OpenStack image to use"
}

variable "key_pair" {
  default     = "docker"
  description = "ssh key pair"
}

variable "private_key" {
  default     = "../ssh/id_docker"
  description = "private ssh key file"
}
