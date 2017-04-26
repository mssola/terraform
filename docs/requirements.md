# Requirements

## Packages

* First and foremost, you need [Terraform](https://github.com/hashicorp/terraform)
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
You can add this repo and install these packages with just

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

## Images

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
