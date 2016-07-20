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

Some aspects of the cluster can be configured by using Terraform
variables. All these variables are defined inside of
`<provider>/variables.tf`, but there's no need to change the file:
you can simply set them using environment variables.

Examples:
```
$ export TF_VAR_name="value"
$ cd <provider> && terraform <command>
```

For more information checkout [this](https://www.terraform.io/docs/configuration/variables.html)
section of terraform's documentation.

### Avoiding name clashes

By default all the VMs provisioned by Terraform are going to be named in the
same way (eg: `kube-master`, `etcd1`, `etcd2`,...). This makes impossible for
multiple people to deploy a Kubernetes cluster on the same cloud.

This can be solved by setting the `cluster_prefix` variable to something like
`flavio-`.

### Configuring the size of the etcd cluster

By default the etcd cluster is composed by 3 nodes. However it's possible to
change the default value by using the `etcd_cluster_size` variable.

### Configuring the number of k8s minions

By default the k8s cluster has 3 k8s minions. However it's possible to
change the default value by using the `kube_minions_size` variable.

## Deploying the cluster

Unfortunately there isn't yet a way to bring up the whole cluster with one
single command.

It's necessary to first create the infrastructure and then to configure the
machines via salt.

### Creating the infrastructure

Follow the instructions for [OpenStack](openstack/README.md) or [libvirt](libvirt/README.md).
For example, for OpenStack you should `cd openstack && terraform apply`.

### Certificates

Regular users should just run the `/srv/salt/certs/certs.sh` script (see below),
but you can find a step-by-step description of all the certificates needed in
[this document](docs/certs.md).

### Running Salt orchestrator

Once all the virtual machines are up and running it's time to configure them.

We are going to use the [Salt orchestration](https://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#orchestrate-runner)
to implement that.

Just execute the following snippet (replacing `<provider>` by the provider you are using):

```
### Connect to the remote salt server
$ cd <provider> && ssh -i ../ssh/id_docker root@`terraform output salt-fip`
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
$ kubectl -s http://`terraform output kube-master-fip`:8080 get pods
```

There's however a more convenient way to use `kubelet`, we can use a dedicated
profile for this cluster. You can read
[here](https://coreos.com/Kubernetes/docs/latest/configure-kubectl.html) how
it's possible to configure kubelet.

Inside of this project there's a `.envrc` file. This is a shell profile that
can be automatically be loaded by [direnv](http://direnv.net/). Once you install
`direnv` you won't have to type anything, just enter the directory and start
using `kubectl` without any special parameter.

You can install direnv from the [utilities](https://build.opensuse.org/package/show/utilities/direnv)
project. Note well, you will need to have `terraform` installed in order to
get everything working.

## Project structure

### Managing the salt subtree

You can pull any new changes in the k8s subtree with:

```
git subtree pull --prefix salt gitlab@gitlab.suse.de:docker/k8s-salt.git   master --squash
```
