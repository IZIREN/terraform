# the provider
provider = "openstack"

# Use it to avoid clashes on the same libvirt instance - use something like '<USER>-k8s'"
# note: this should not start/end with non-alpha characters
cluster_prefix = ""

#######################
# cluster sizes
#######################
etcd_cluster_size = 3
kube_minions_size = 3

#######################
# openstack
#######################
# the base image
openstack_image = "openSUSE-Leap-42.1"

# ssh key pair name and private ssh key file
key_pair = "docker"
private_key = "../ssh/id_docker"
