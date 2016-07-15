# prepend the "base-libvirt.profile" with
# k8s-setup -F base-libvirt.profile -F libvirt-jeos-magnum.profile

#######################
# libvirt
#######################
volume_base = ""
volume_source = "http://download.suse.de/ibs/Devel:/Docker:/Images:/SLE12SP1-JeOS-k8s-magnum/images/SLE12SP1-JeOS-k8s-magnum.x86_64.qcow2"

# is the image an UEFI image? then you need a valid firmware
is_uefi_image = yes
firmware = "/usr/share/qemu/ovmf-x86_64-code.bin"
