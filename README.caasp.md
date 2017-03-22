# _CaaSP_ / _MicroOS_

## Images

You can try the _CaaSP_/_MicroOS_ images with the help of the
[`libvirt-caasp.profile`](libvirt-caasp.profile) profile. You can then
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
Salt scripts) while the Terraform code here insists on copying stuff to
the VMs. That forces us to use some specific manifest files (i.e., for
the Salt master) that mount the files we are copying instead of the
files already present in the image.
