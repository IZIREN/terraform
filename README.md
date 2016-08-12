# Terraform provisioning for Kubernetes

This project includes [Terraform](https://www.terraform.io) scripts for
deploying Kubernetes on top of [OpenStack](https://www.openstack.org/)
or [libvirt](http://libvirt.org/). This is not using
[Magnum](https://wiki.openstack.org/wiki/Magnum) yet.

The deployment consists of:

  * *salt server*: used to configure all the nodes
  * *etcd cluster*: the number of nodes can be configured
  * *kube-master*
  * *kube-minions*: the number of nodes can be configured

A packaged version of Terraform can be found on OBS inside of the
[Virtualization:containers](https://build.opensuse.org/project/show/Virtualization:containers) project.

## Cluster configuration

### `k8s-setup` script

The Kubernetes infrastructure is managed with _Terraform_, but
we use a ruby script, `k8s-setup`, for preprocessing the
Terraform scripts, replacing variables and conditionally
including some files.

This script processes all the `*.tf` and `*.tf.erb` files
found in the _terraforms directory_ (by default, `$(pwd)/terraform`)
and generate a unique output file (by default, `k8s-setup.tf`). As a
shortcut, it also runs `terraform` with the last arguments provided,
so running `k8-setup plan` is equivalent to `k8s-setup && terraform plan`.

### Variables

Some aspects of the cluster can be configured by using variables.
These variables can be provided to the `k8s-setup` script
with `-V variable=value` arguments, or through a configuration
file. See the example files provided in the repository for more
details.

Some important variables are:

  * `salt_dir`

    The directory where the Salt scripts are (usually a checkout of [this
    repo](https://gitlab.suse.de/docker/k8s-salt))

  * `ssh_dir`

    The directory where the ssh keys are (by default, the local `ssh` directory)

  * `cluster_prefix`

    By default all the VMs provisioned by Terraform are going to be named in the
    same way (eg: `kube-master`, `etcd1`, `etcd2`,...). This makes impossible for
    multiple people to deploy a Kubernetes cluster on the same cloud.

    This can be solved by setting the `cluster_prefix` variable to something like
    `flavio-`.

  * `etcd_cluster_size`

    By default the etcd cluster is composed by 3 nodes. However it's possible to
    change the default value by using the `etcd_cluster_size` variable.

  * `kube_minions_size`

    By default the k8s cluster has 3 k8s minions. However it's possible to
    change the default value by using the `kube_minions_size` variable.

  * `bridge`

    Name of the bridge interface to use when creating the nodes. This is useful
    when the libvirt host is a remote machine different from the one running
    terraform.

Please take a look at the `*.profile` files for more variables used in
our templates.

## Deploying the cluster

Unfortunately there isn't yet a way to bring up the whole cluster with one
single command: it's necessary to first create the infrastructure with
_Terraform_ and then to configure the machines via _Salt_.

### Creating the infrastructure

The easiest way to configure your cluster is to use one of the included
`.profile` configuration file and overwrite the variables you need.
Then you can invoke the `k8s-setup` script with any of the commands
accepted by _Terraform_.

For example:

```
$ ./k8s-setup -F base-openstack.profile apply
```

You could for example overwrite `kube_minions_size` by invoking it as:

```
$ ./k8s-setup -V kube_minions_size=6 -F base-openstack.profile apply
```

or with an additional configuration file:

```
$ echo "kube_minions_size=6" > local.profile
$ ./k8s-setup -F base-openstack.profile -F local.profile apply
```

If you want to review the generated `k8s-setup.tf` file, you can also
obtain a prettified version of this file with:

```
$ ./k8s-setup -F base-openstack.profile fmt
```

and then run any `terraform` command with this file.

### Certificates

Regular users should just run the `/srv/salt/certs/certs.sh` script (see below),
but you can find a step-by-step description of all the certificates needed in
[this document](docs/certs.md).

### Running Salt orchestrator

Once all the virtual machines are up and running it's time to configure them.

We are going to use the [Salt orchestration](https://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#orchestrate-runner)
to implement that.

Just execute the following snippet:

```
### Connect to the remote salt server
$ ssh -i ssh/id_docker root@`k8s-setup output fip_salt`
### Generate the certificates
# /srv/salt/certs/certs.sh
### Execute the orchestrator
# salt-run state.orchestrate orch.kubernetes
```

## Using the cluster

The Kubernetes _api-server_ is publicly available. It can be reached on port `8080`
of the floating IP associated to the `kube-master` node.

For example:

```
$ kubectl -s http://`k8s-setup output fip_kube_master`:8080 get pods
```

There's however a more convenient way to use `kubelet`, we can use a dedicated
profile for this cluster. You can read
[here](https://coreos.com/Kubernetes/docs/latest/configure-kubectl.html) how
it's possible to configure kubelet.

## Project structure

### Managing the salt subtree

You can pull any new changes in the k8s subtree with:

```
git subtree pull --prefix salt gitlab@gitlab.suse.de:docker/k8s-salt.git   master --squash
```
