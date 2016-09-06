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

* First and foremost, you need [terraform](https://github.com/hashicorp/terraform)
installed.
* When using a **libvirt** environment, you will also need the
[terraform-provider-libvirt](https://github.com/dmacvicar/terraform-provider-libvirt)
package. These two packages are available on OBS inside of the
[Virtualization:containers](https://build.opensuse.org/project/show/Virtualization:containers) project.
* If you are using an **openstack** environment with **cloud.suse.de**, then you need
to get the internal root certificates from SUSE. You can do this by installing
the [ca-certificates-suse](https://api.suse.de/package/show/SUSE:CA/ca-certificates-suse)
package found in the [ibs://SUSE:CA](https://api.suse.de/project/show/SUSE:CA) project.

#### Projects

* In order to provision the virtual machines, we use salt. In particular, we have
our own repository for salt scripts needed for installing a proper Kubernetes
cluster: https://gitlab.suse.de/docker/k8s-salt. As it's described later in the
`Variables` section, you may use the `salt_dir` variable to point to a local
checkout of the `k8s-salt` project.

### Images

One important aspect of the configuration is the image you will use for
your VMs. This is specially important in some configurations and is the main
source of problems, so the recommended solution is to use some of the images
already provided by the Docker team.

* When using *cloudinit*, the image should start the *cloudinit* services
  automatically.
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

### Configuration Variables

Some aspects of the cluster can be configured by using variables.
These variables can be provided to the `k8s-setup` script
with `-V variable=value` arguments, or through a _profile
file_. See the example files provided in the repository for more
details.

Some important variables are:

  * `salt_dir`

    The directory where the Salt scripts are (usually a checkout of [this
    repo](https://gitlab.suse.de/docker/k8s-salt))

  * `ssh_key`

    `ssh_key` is the key we will use for accessing machines (by default,
    the `id_docker` in the local `ssh` directory)

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

  * `cloudinit`

    When defined to `true` it will enable *cloudinit*. [cloudinit](https://cloudinit.readthedocs.io/en/latest/)
    is required in some configurations (ie, _libvirt_ with _bridged network_),
    specially for setting up the DNS names for the VMs. *cloudinit* needs
    images with the appropriate services running, so make sure this variable
    matches the image you use for your VMs.

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

Once all the virtual machines are up and running it's time to install
software and configure them. We do that with the help of the [Salt orchestration](https://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#orchestrate-runner).
Just execute:

```
# Make sure that the SSH key is only accessible by you, otherwise ssh will complain
$ chmod 0400 ssh/id_docker
$ ssh -i ssh/id_docker root@`terraform output ip_salt` \
    bash /tmp/salt/provision-salt-master.sh --finish
```

Then follow the instructions given by the provisioning script.

Notes:

* the certificate generated for the API server includes the list of IPs
automatically detected by provisioning script. However, this is not enough
in some cases when the API server will be accessed at some other IP
(for example, when the server is behind a NAT or when a _floating IP_ is
assigned to it in a _OpenStack_ cluster). In those cases, you should
specify that IP in with `--extra-api-ip <IP>`.

## Using the cluster

The Kubernetes _API server_ can be used by configuring the `kubectl`
with a `kubeconfig` file. Copy the `admin.tar` file from the Salt master,
uncompress it and export the `KUBECONFIG` variable.

For example:

```
$ scp -i ssh/id_docker root@`terraform output ip_salt`:admin.tar .
$ tar xvpf admin.tar
$ KUBECONFIG=kubeconfig kubectl get nodes
```
