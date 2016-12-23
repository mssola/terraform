#!/bin/sh

set -e

if [ "$#" != 1 ]; then
    echo "Expected one argument"
    exit 1
fi

# Variables for master and minion nodes.
MASTER_MEMORY="$MASTER_MEMORY"
[ -z "$MASTER_MEMORY" ] && MASTER_MEMORY=2048
MINIONS_SIZE="$MINIONS_SIZE"
[ -z "$MINIONS_SIZE" ] && MINIONS_SIZE=2
MINION_MEMORY="$MINION_MEMORY"
[ -z "$MINION_MEMORY" ] && MINION_MEMORY=2048

# If the project is like "k8s-terraform-stable", then the prefix is `stable`.
# Otherwise, we stick to the current username.
prefix="$(echo "${PWD##*/}" | awk -F- '{ print $3; }')"
if [ "$prefix" = "" ]; then
    prefix="$USER"
fi

if [ "$1" == "apply" ]; then
	# Get the salt directory, which is a separate repo.
	SALT_PATH="${SALT_PATH:-$PWD/../k8s-salt}"
	if ! [ -d "$SALT_PATH" ]; then
		echo "[+] Downloading k8s-salt to '$SALT_PATH'"
		git clone gitlab@gitlab.suse.de:docker/k8s-salt "$SALT_PATH"
	else
		echo "[*] Already downloaded k8s-salt at '$SALT_PATH'"
	fi

	# Get the right VM image from IBS.
	IMAGE_PATH="${IMAGE_PATH:-$PWD/Base-SLES12-SP2.x86_64-cloud_ext4.qcow2}"
	#IMAGE_PATH="${IMAGE_PATH:-$PWD/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2}"
	if ! [ -f "$IMAGE_PATH" ]; then
		echo "[+] Downloading SUSE qcow2 VM image to '$IMAGE_PATH'"
		wget -O "$IMAGE_PATH" "http://download.suse.de/ibs/Devel:/Docker:/Images:/terraform:/SLE-12/images_SLE12_SP2/Base-SLES12-SP2.x86_64-cloud_ext4.qcow2"
        #wget -O "$IMAGE_PATH" "http://download.opensuse.org/repositories/Virtualization:/containers:/images:/KVM:/Leap:/42.2/images/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2"
	else
		echo "[*] Already downloaded SUSE qcow2 VM image to '$IMAGE_PATH'"
	fi

	# Make sure that libvirt is started.
	# While this probably shouldn't be in this script, meh.
	sudo systemctl start libvirtd.service virtlogd.socket virtlockd.socket || :
fi

# Always in debug mode.
export TF_LOG=debug

# Go kubes go!
./k8s-setup \
    --verbose \
    -F libvirt-obs.profile \
    -V salt_dir="$SALT_PATH" \
    -V cluster_prefix=$prefix \
    -V master_memory=$MASTER_MEMORY \
    -V kube_minions_size=$MINIONS_SIZE \
    -V minion_memory=$MINION_MEMORY \
    -V volume_source="$IMAGE_PATH" \
    $1


if [ "$1" != "apply" ]; then
    exit $?
fi

notify-send "The infrastructure is up, running Salt!"

# Salt + obtain the admin.tar file.

ssh -i ssh/id_docker \
    -o "StrictHostKeyChecking no" \
    -o "UserKnownHostsFile /dev/null" \
    root@`terraform output ip_dashboard` \
    bash /tmp/provision-dashboard.sh --finish

scp -i ssh/id_docker \
    -o "StrictHostKeyChecking no" \
    -o "UserKnownHostsFile /dev/null" \
    root@`terraform output ip_dashboard`:admin.tar .

tar xvpf admin.tar

echo "Everything is fine, enjoy your cluster!"

if [ -z "$(which kubectl)" ]; then
    echo "Install the kubernetes-client package and then run " \
         "\"export KUBECONFIG=kubeconfig\" to use this cluster."
else
    echo "Execute the following to use this cluster: export KUBECONFIG=kubeconfig"
fi
