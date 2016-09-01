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

## Requirements

### Environment

#### Packages

First and foremost, you need [terraform](https://github.com/hashicorp/terraform)
installed. Plus, if you are using the **libvirt** setup, you will also need the
[terraform-provider-libvirt](https://github.com/dmacvicar/terraform-provider-libvirt)
package. These two packages are available on OBS inside of the
[Virtualization:containers](https://build.opensuse.org/project/show/Virtualization:containers) project.

If you are using the **openstack** method with **cloud.suse.de**, then you need
to get the internal root certificates from SUSE. You can do this by installing
the [ca-certificates-suse](https://api.suse.de/package/show/SUSE:CA/ca-certificates-suse)
package found in the [ibs://SUSE:CA](https://api.suse.de/project/show/SUSE:CA) project.

#### Projects

In order to provision the virtual machines, we use salt. In particular, we have
our own repository for salt scripts needed for installing a proper Kubernetes
cluster: https://gitlab.suse.de/docker/k8s-salt. As it's described later in the
`Variables` section, you may use the `salt_dir` variable to point to a local
checkout of the `k8s-salt` project.

### Images

One important aspect of the configuration is the image you will use for
your VMs. This is specially important in some configurations and is the main
source of problems, so the recommended solution is to use some of the images
already provided by the Docker team.

* The image must start the **cloudinit** services automatically.
* When using _libvirt_, they _should_ have the `qemu-agent` installed (otherwise
  they will not work in _bridged mode_)
* In development environments, they _should_ be accessible with
  `user`/`pass`=`root`/`vagrant`

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
with `-V variable=value` arguments, or through a _profile
file_. See the example files provided in the repository for more
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
`.profile` configuration files and overwrite the variables you need.
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

Notes:

* the certificate generated for the API server includes the list of IPs
automatically detected by `certs.sh` script. However, this is not enough
in some cases when the API server will be accessed some other IP
(for example, when the server is behind a NAT or when it is accessed
though a _floating IP_ in a _OpenStack_ cluster). In those cases, you should
specify that IP in the environment variable, `EXTRA_API_SRV_IP`, before
invoking the `certs.sh` script.

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
