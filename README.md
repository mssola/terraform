# Terraform provisioning for Kubernetes

This project includes [Terraform](https://www.terraform.io) scripts for
deploying Kubernetes on top of [OpenStack](https://www.openstack.org/)
or [libvirt](http://libvirt.org/). This is not using
[Magnum](https://wiki.openstack.org/wiki/Magnum) yet.

The deployment consists of:

  * *salt server*: used to configure all the nodes
  * *kube-master*
  * *kube-minions*: the number of nodes can be configured

## Requirements

### Environment

#### Packages

* First and foremost, you need [terraform](https://github.com/hashicorp/terraform)
installed.
* When using a **libvirt** environment, you will also need the
[terraform-provider-libvirt](https://github.com/dmacvicar/terraform-provider-libvirt)
package.
* In order to provision the virtual machines, we use [Salt](https://saltstack.com/).
In particular, we have [our own repository](https://github.com/kubic-project/salt)
for the Salt scripts needed for installing a proper Kubernetes cluster.
As it's described later in the `Variables` section, you may use the
`salt_dir` variable to point to a local checkout of the
`kubic-project/salt` project.

All these dependencies are already packaged in OBS inside of the
[Virtualization:containers](https://build.opensuse.org/project/show/Virtualization:containers) project.
You could add this repo and install these packages with just

```
$ # (replace openSUSE_Leap_42.2 with your distro)
$ sudo zypper ar http://download.opensuse.org/repositories/Virtualization:/containers/openSUSE_Leap_42.2 containers
$ sudo zypper in terraform terraform-provider-libvirt kubernetes-salt
```

Then you can install the latest packaged version of this repository by installing

```
$ sudo zypper in kubernetes-terraform
```

* If you are using an **OpenStack** environment with **cloud.suse.de**, then
you must install the internal root certificates from SUSE. You can do this by
installing the [ca-certificates-suse](https://api.suse.de/package/show/SUSE:CA/ca-certificates-suse)
package found in the [ibs://SUSE:CA](https://api.suse.de/project/show/SUSE:CA) project.

### Images

One important aspect of the configuration is the image you will use for
your VMs. This is specially important in some configurations and is the main
source of problems, so the recommended solution is to use some of the images
already provided by the Docker team.

* Since we rely on *cloudinit*, the image should start the *cloudinit* services
  automatically. The minimum cloud-init version supported is 0.7.7.
* When using _libvirt_, they _should_ have the `qemu-agent` installed (otherwise
  they will not work in _bridged mode_)
* In development environments, they _should_ be accessible with
  `user`/`pass`=`root`/`vagrant`

#### _CaaSP_/_MicroOS_ images

You can try the _CaaSP_/_MicroOS_ images with the help of the
[`libvirt-caasp.profile`](libvirt-caasp.profile) profile. You can the
run something similar to:

```
$ cd terraform && ./k8s-setup -v \
    -F libvirt-caasp.profile \
    -V salt_dir=`pwd`/k8s-salt \
    -V ssh_key=`pwd`/ssh/id_docker \
    -V volume_pool=personal \
    -V kube_minions_size=2 \
    -V cluster_prefix=caasp \
    -V net_cidr=10.17.15.0/24 \
    fmt
$ terraform apply
$ # now you should have the VMs ready
$ ssh -i `pwd`/ssh/id_docker  root@`terraform output ip_dashboard`
$ # in the dashboard machine
$ cd /tmp && sh ./provision-dashboard.sh --finish --color
```

Make sure the `volume_source` in the profile points to a valid image URL.

You must take into account that the environment created is similar but
not the same as a real _CaaSP_/_MicroOS_ cluster. For example, some
things are already installed in the _CaaSP_/_MicroOS_ images (like the
Salt scripts) while the Terraform code here insist in copying stuff to
the VMs. That forces us to use some specific manifest files (ie, for
the Salt master) that mount the files we are copying instead of the
files already present in the image.

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

### Helper script for libvirt

You should be using the `k8s-setup` script to manage your Kubernetes
cluster. That being said, if you are going to use the `libvirt` driver, you
might want to take a look at the [k8s-libvirt](contrib/libvirt/k8s-libvirt.sh)
script. This script assumes that you want to use libvirt, and it makes some
assumptions that will allow you to deploy your cluster with a simple command.

### Configuration Variables

Some aspects of the cluster can be configured by using variables.
These variables can be provided to the `k8s-setup` script
with `-V variable=value` arguments, or through a _profile
file_. See the example files provided in the repository for more
details.

Some important variables are:

  * `salt_dir`

    The directory where the Salt scripts are (`/usr/share/salt/kubernetes`
    when installing the `kubernetes-salt` RPM, or a checkout of [this
    repo](https://github.com/kubic-project/salt))

  * `ssh_key`

    `ssh_key` is the key we will use for accessing machines (by default,
    the `id_docker` in the local `ssh` directory)

  * `cluster_prefix`

    By default all the VMs provisioned by Terraform are going to be named in the
    same way (eg: `kube-master`, `kube-minion1`, `kube-minion2`,...). This makes
    impossible for multiple people to deploy a Kubernetes cluster on the same cloud.

    This can be solved by setting the `cluster_prefix` variable to something like
    `flavio-`.

  * `cluster_domain_name`

    The cluster default domain name. It can be something like `k8s.local`. This
    domain name will be used across all the instances.

  * `kube_minions_size`

    By default the k8s cluster has 3 k8s minions. However it's possible to
    change the default value by using the `kube_minions_size` variable.

  * `bridge`

    Name of the bridge interface to use when creating the nodes. This is useful
    when the libvirt host is a remote machine different from the one running
    terraform.

  * `<component name>_memory`

    The amount of memory to be assigned to the given component in MB. Possible
    options for components are: `master`, `minion` and `salt`. The default value
    is 512 MB. Moreover, if you want to setup the same value for all of them,
    you can use the `memory` shortcut. **Note**: this only works for the libvirt
    setup. Support for openstack is still being worked.

  * `docker_reg_mirror`

    An (optional) Docker registry mirror (ie, `myserver:5000`). This can be
    specially helpful when you intend to download many Docker images and
    bandwidth is scarce.

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

### Running Salt orchestrator

Once all the virtual machines are up and running it's time to install
software and configure them. We do that with the help of the [Salt orchestration](https://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#orchestrate-runner).
Just execute:

```
$ ssh -i ssh/id_docker root@`terraform output ip_dashboard` \
    bash /tmp/salt/provision-dashboard.sh --finish
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
$ scp -i ssh/id_docker root@`terraform output ip_dashboard`:admin.tar .
$ tar xvpf admin.tar
$ KUBECONFIG=kubeconfig kubectl get nodes
```

## License

This project is licensed under the Apache License, Version 2.0. See
[LICENSE](https://github.com/kubic-project/salt/blob/master/LICENSE) for the full
license text.
