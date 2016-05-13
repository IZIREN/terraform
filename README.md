# Kubernetes on OpenStack

This is a sample deployment of kubernetes on top of OpenStack. This is not using
Magnum, since we don't have it yet ;)

The deployment consists of:

  * salt server: used to configure all the nodes
  * etcd cluster: the number of nodes can be configured
  * kube-master
  * kube-minions: the number of nodes can be configured

The whole infrastructure can be deployed using [terraform](https://www.terraform.io).
A packaged version of terraform can be found on OBS inside of the
Virtualization:containers project.

## Cluster configuration

Some aspects of the cluster can be configured by using terraform
variables.

All the variables are defined inside of `variables.tf`.

There's no need to change the file, you can simply set them using
environment variables.

Examples:
```
$ export TF_VAR_name="value"
$ terraform <command>
```

For more information checkout [this](https://www.terraform.io/docs/configuration/variables.html)
section of terraform's documentation.

### Avoiding name clashes

By default all the VMs provisioned by terraform are going to be named in the
same way (eg: `kube-master`, `etcd1`, `etcd2`,...). This makes impossible for
multiple people to deploy a kubernetes cluster on the same cloud.

This can be solved by setting the `cluster-prefix` variable to something like
`flavio-`.

### Configuring the size of the etcd cluster

By default the etcd cluster is composed by 3 nodes. However it's possible to
change the default value by using the `etcd-cluster-size` variable.

### Configuring the number of k8s minions

By default the k8s cluster has 3 k8s minions. However it's possible to
change the default value by using the `kube-minions-size` variable.

## Deploying the cluster

Unfortunately there isn't yet a way to bring up the whole cluster with one
single command.

It's necessary to first create the infrastructure and then to configure the
machines via salt.

### Creating the infrastructure

First of all download your [OpenStack RC file](https://cloud.suse.de/project/access_and_security/api_access/openrc/).

Then load it:

```
$ source appliances.rc
```

and finally provision the whole infrastructure:

```
$ terraform plan # see what is going to happen
$ terraform apply # apply the operations
```

If you make changes to the default infrastructure you are encouraged to commit
the `terraform.tfstate` and `terraform.tfstate.backup` to git.

### Generating the certificates

You must generate certificates for your Kubernetes components in order to
use secure connections. You can run the certificates generation script
in the Salt master with:

    $ ssh -i ssh/id_docker root@`terraform output salt-fip` /srv/salt/certs/certs.sh --all

This will generate certificates for the root CA, API server and all the minions.

### Running salt orchestrator

Once all the virtual machines are up and running it's time to configure them.

We are going to use the [salt orchestration](https://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#orchestrate-runner)
to implement that.

Just execute the following snippet:

```
# Connect to the remote salt server
$ ssh -i ssh/id_docker root@`terraform output salt-fip`
# Execute the orchestrator
# salt-run state.orchestrate orch.kubernetes
```

## Using the cluster

The kubernetes api-server is publicly available. It can be reached on port `8080`
of the floating IP associated to the `kube-master` node.

For example:

```
$ kubectl -s http://`terraform output kube-master-fip`:8080 get pods
```

There's however a more convenient way to use `kubelet`, we can use a dedicated
profile for this cluster. You can read
[here](https://coreos.com/kubernetes/docs/latest/configure-kubectl.html) how
it's possible to configure kubelet.

Inside of this project there's a `.envrc` file. This is a shell profile that
can be automatically be loaded by [direnv](http://direnv.net/). Once you install
`direnv` you won't have to type anything, just enter the directory and start
using `kubectl` without any special parameter.

You can install direnv from the [utilities](https://build.opensuse.org/package/show/utilities/direnv)
project. Note well, you will need to have `terraform` installed in order to
get everything working.

