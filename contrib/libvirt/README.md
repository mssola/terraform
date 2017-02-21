# The `k8s-libvirt` script

This script wraps the `k8s-setup` script by applying some default values and
performing some checks. Moreover this script also performs the needed salt calls
so everything is properly up and running. This script takes one argument, which
will be directly passed to the `k8s-setup` script. Finally, this script uses the
*libvirt* setup (check [this](#libvirt) section to learn how to setup libvirt).

With all this mind, the workflow for setting up a Kubernetes cluster is as
follows:

```
$ contrib/libvirt/k8s-libvirt.sh apply
$ export KUBECONFIG=cluster-config/kubeconfig
$ kubectl get nodes
```

Some weird things:

- The **cluster_prefix** is taken from the current directory. If it's named
  `k8s-terraform`, then your current login will be picked up as the
  prefix. Otherwise, if it's named `k8s-terraform-stable`, then the prefix will
  be *stable*.
- **debug mode** in terraform is enabled. Not really needed, and if it's the first
  time you use terraform, you will be kind of scared :P

`k8s-setup` is called with the following flags:

- The `salt_dir` points to a local copy of
  [k8s-salt](https://gitlab.suse.de/docker/k8s-salt). This is helpful if you are
  also messing with the `k8s-salt` repository. The local copy of `k8s-salt` is
  supposed to be on the same directory as your local `k8s-terraform` copy. If
  that's not the case, you can provide the `SALT_PATH` environment variable.
- The path to the image to be used is taken from the `IMAGE_PATH` environment
  variable. If this is not defined, a SLE12 image will be downloaded and used.
- All nodes are given 2GiB of RAM memory by default. We consider this to be a
  good default for regular deployments. You can change that with the
  `MASTER_MEMORY` and `MINION_MEMORY` environment variables.
- We are using 2 minion nodes. You can change this with the `MINIONS_SIZE`
  environment variable.
- If you want to run the terraform provisioning in debug mode, you can export
  the `TF_DEBUG` environment variable set to any value.
- By default all images used are SUSE Linux Enterprise (SLE), but you can use
  `FLAVOUR` environment variable set to `opensuse` if you prefer to use
  opensuse as the base image for all virtual machines.
- You can also set `SKIP_ORCHESTRATION` to avoid setting roles to machines and
  to avoid running a orchestration automatically.
- If you want to completely skip the creation of a dashboard machine you can
  set `SKIP_DASHBOARD`, so only minion machines will be created. In this case you
  can also set `DASHBOARD_HOST` to make this minion machines point to the host
  that you want. This can effectively reduce the creation time of the cluster,
  making it straightforward to develop along with [the velum dashboard](https://github.com/kubic-project/velum).
- To cleanup you can run `contrib/libvirt/k8s-libvirt.sh destroy`. This will
  bring up a dialog that will ask for confimation. If you want to destroy without
  dialogs (as you would from some other script), you can set the FORCE environment
  variable: `FORCE=true contrib/libvirt/k8s-libvirt.sh destroy`

## Examples

### Run a whole cluster running orchestration automatically

This creates a dashboard, a kubernetes-master and 2 minions. It will run the
orchestration in the dashboard machine, inside the salt-master container.

#### SLE
`MINIONS_SIZE=2 contrib/libvirt/k8s-libvirt.sh apply`

#### openSUSE
`FLAVOUR=opensuse MINIONS_SIZE=2 contrib/libvirt/k8s-libvirt.sh apply`

### Run a whole cluster skipping orchestration

This creates a dashboard, a kubernetes-master and 2 minions. This will skip the
role assigning of machines and the orchestration run.

#### SLE
`SKIP_ORCHESTRATION=1 MINIONS_SIZE=2 contrib/libvirt/k8s-libvirt.sh apply`

#### openSUSE
`SKIP_ORCHESTRATION=1 FLAVOUR=opensuse MINIONS_SIZE=2 contrib/libvirt/k8s-libvirt.sh apply`

### Run a tiny cluster

This creates 2 minions. No dashboard machine will be created, so you will need to specify
where the salt-master is running, so those minions will be able to report back to that
salt-master instance.

#### SLE
`DASHBOARD_HOST=192.168.X.Y SKIP_DASHBOARD=1 MINIONS_SIZE=2 contrib/libvirt/k8s-libvirt.sh apply`

#### openSUSE
`DASHBOARD_HOST=192.168.X.Y SKIP_DASHBOARD=1 FLAVOUR=opensuse MINIONS_SIZE=2 contrib/libvirt/k8s-libvirt.sh apply`

## Libvirt setup

You need to have the following packages (here's the zypper command-line for it).
I would recommend taking the packages directly from `Virtualization:containers`
at the moment. Also I would recommend running this openSUSE Leap:

```
% zypper ar http://download.opensuse.org/repositories/Virtualization:/containers/openSUSE_Leap_42.1 obs-virtualization-containers
Adding repository 'obs-virtualization-containers' .......................[done]
Repository 'obs-virtualization-containers' successfully added
Enabled     : Yes
Autorefresh : No
GPG Check   : Yes
URI         : http://download.opensuse.org/repositories/Virtualization:/containers/openSUSE_Leap_42.1
% zypper mr --refresh obs-virtualization-containers
Autorefresh has been enabled for repository 'obs-virtualization-containers'.
% zypper in libvirt{,-daemon,-client} qemu-kvm terraform{,-provider-libvirt} ruby wget git
[ install all the things ]
```

In order to setup libvirt run the following commands:

```bash
% usermod -a -G libvirt $(whoami)
% newgrp libvirt # to get required privs
% mkdir -p /var/lib/libvirt/images
% sudo virsh 'pool-create-as default dir --target /var/lib/libvirt/images'
```

You should now have enough packages to run the above script.

> **NOTE**: Currently `libvirt >= 2.0` only works if you are using a
> terraform-provider-libvirt version
> after [this](https://github.com/dmacvicar/terraform-provider-libvirt/pull/86) PR.

In addition, please make sure that you have VT-x enabled in your BIOS.
Otherwise you'll get errors about not being able to match `kvm` capabilities.
