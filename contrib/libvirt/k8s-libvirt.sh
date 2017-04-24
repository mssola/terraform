#!/bin/sh

set -e

if [ "$#" != 1 ]; then
    echo "Expected one argument"
    exit 1
fi

CLUSTER_CONF_DIR=$(pwd)/cluster-config

# Variables for master and minion nodes.
MINIONS_SIZE=${MINIONS_SIZE:-2}
DASHBOARD_CPUS=${DASHBOARD_CPUS:-1}
MASTER_CPUS=${MASTER_CPUS:-1}
MINION_CPUS=${MINION_CPUS:-1}
DASHBOARD_MEMORY=${DASHBOARD_MEMORY:-2048}
MASTER_MEMORY=${MASTER_MEMORY:-2048}
MINION_MEMORY=${MINION_MEMORY:-2048}
FLAVOUR=${FLAVOUR:-"caasp"}
DASHBOARD_HOST=${DASHBOARD_HOST:-}
SKIP_DASHBOARD=${SKIP_DASHBOARD:-"false"}
SKIP_ORCHESTRATION=${SKIP_ORCHESTRATION:-"false"}

[ "$SKIP_DASHBOARD" != "false" ] && SKIP_DASHBOARD="true"
[ "$SKIP_ORCHESTRATION" != "false" ] && SKIP_ORCHESTRATION="true"
[ "$LATEST_IMAGE" != "false" ] && LATEST_IMAGE="true"

SSH_DEFAULT_ARGS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

# Fix ssh directory/keys permissions (git ignores some permission changes)
chmod 700 ssh
chmod 644 ssh/id_docker.pub
chmod 600 ssh/id_docker

# If PREFIX is set we use that as a prefix else if the project is like
# "k8s-terraform-stable", then the prefix is `stable`.
# Otherwise, we stick to the current username.
prefix="$(echo "${PWD##*/}" | awk -F- '{ print $3; }')"
if [ ! -z ${PREFIX+x} ]; then
  prefix="$PREFIX"
elif [ "$prefix" = "" ]; then
  prefix="$USER"
fi

if [ "$1" == "apply" ]; then
    # Get the salt directory, which is a separate repo.
    SALT_PATH="${SALT_PATH:-$PWD/../salt}"
    if ! [ -d "$SALT_PATH" ]; then
        echo "[+] Downloading kubic-project/salt to '$SALT_PATH'"
        git clone https://github.com/kubic-project/salt "$SALT_PATH"
    else
        echo "[*] Already downloaded kubic-project/salt at '$SALT_PATH'"
    fi

    if [ "$FLAVOUR" == "opensuse" ]; then
        IMAGE_PATH="${IMAGE_PATH:-$PWD/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2}"
    elif [ "$FLAVOUR" == "caasp" ]; then
        IMAGE_PATH="${IMAGE_PATH:-$PWD/SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64.qcow2}"
    fi

    if ! [ -f "$IMAGE_PATH" ] || [ "$LATEST_IMAGE" == "true" ]; then
        if [ "$FLAVOUR" == "opensuse" ]; then
            echo "[+] Downloading openSUSE qcow2 VM image to '$IMAGE_PATH'"
            wget -q -O "$IMAGE_PATH" -N "http://download.opensuse.org/repositories/Virtualization:/containers:/images:/KVM:/Leap:/42.2/images/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2"
        elif [ "$FLAVOUR" == "caasp" ]; then
            echo "[+] Downloading SUSE CaaSP qcow2 VM image to '$IMAGE_PATH'"
            wget -q -r -l1 -nd -N "http://download.suse.de/ibs/SUSE:/SLE-12-SP2:/Update:/Products:/CASP10/images/" -P /tmp/CaaSP -A "SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64*qcow2"
            find /tmp/CaaSP -name "SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64*qcow2" -prune -exec mv {} $IMAGE_PATH ';'
        fi
    else
        if [ "$FLAVOUR" == "opensuse" ]; then
            echo "[*] Already downloaded openSUSE qcow2 VM image to '$IMAGE_PATH'"
        elif [ "$FLAVOUR" == "caasp" ]; then
            echo "[*] Already downloaded SUSE CaaSP qcow2 VM image to '$IMAGE_PATH'"
        fi
    fi

    # Make sure that libvirt is started.
    # While this probably shouldn't be in this script, meh.
    sudo systemctl start libvirtd.service virtlogd.socket virtlockd.socket || :
fi

# Select the profile file depending on the flavour.
if [ "$FLAVOUR" == "caasp" ]; then
    profile="libvirt-caasp.profile"
else
    profile="libvirt-obs.profile"
fi

[ -n "$TF_DEBUG" ] && export TF_LOG=debug
[ -n "$FORCE" ] && force="--force"

# Go kubes go!
./k8s-setup \
    --verbose \
    $force \
    -F $profile \
    -V salt_dir="$SALT_PATH" \
    -V cluster_prefix=$prefix \
    -V skip_dashboard=$SKIP_DASHBOARD \
    -V kube_minions_size=$MINIONS_SIZE \
    -V dashboard_cpus=$DASHBOARD_CPUS \
    -V dashboard_memory=$DASHBOARD_MEMORY \
    -V master_cpus=$MASTER_CPUS \
    -V master_memory=$MASTER_MEMORY \
    -V minion_cpus=$MINION_CPUS \
    -V minion_memory=$MINION_MEMORY \
    -V volume_source="$IMAGE_PATH" \
    -V dashboard_host=$DASHBOARD_HOST \
    -V skip_role_assignments=$SKIP_ORCHESTRATION \
    $1

if [ "$1" != "apply" ]; then
    exit $?
fi

if which notify-send >/dev/null; then
    notify-send "The infrastructure is up, running Salt!"
else
    echo "The infrastructure is up, running Salt!"
fi

if [ $SKIP_ORCHESTRATION == "false" ] && [ $SKIP_DASHBOARD == "false" ]; then
    ssh -i ssh/id_docker \
        $SSH_DEFAULT_ARGS \
        root@`terraform output ip_dashboard` \
        bash /tmp/provision-dashboard.sh --finish

    mkdir -p "$CLUSTER_CONF_DIR"
    scp -i ssh/id_docker \
        $SSH_DEFAULT_ARGS \
        root@`terraform output ip_dashboard`:admin.tar "$CLUSTER_CONF_DIR/"

    tar xvpf $CLUSTER_CONF_DIR/admin.tar -C "$CLUSTER_CONF_DIR"

    echo "Everything is fine, enjoy your cluster!"

    if [ -z "$(which kubectl)" ]; then
        echo "Install the kubernetes-client package and then run " \
             "\"export KUBECONFIG=$CLUSTER_CONF_DIR/kubeconfig\" to use this cluster."
    else
        echo "Execute the following to use this cluster: export KUBECONFIG=$CLUSTER_CONF_DIR/kubeconfig"
    fi
else
    echo "Cluster is up, but roles are unassigned and no orchestration was launched"
    echo "  Please, start the dashboard locally"
    echo "  You can now visit http://localhost:3000 and bootstrap the cluster with the dashboard"
fi
