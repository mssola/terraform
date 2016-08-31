# prepend the "base-libvirt.profile" with
# k8s-setup -F base-libvirt.profile -F libvirt-obs.profile

#######################
# libvirt
#######################
volume_base = ""
volume_source = "http://download.opensuse.org/repositories/Virtualization:/containers:/images:/KVM:/Leap:/42.1/images/Base-openSUSE-Leap-42.1-btrfs.x86_64.qcow2"