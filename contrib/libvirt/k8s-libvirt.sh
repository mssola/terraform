#!/bin/sh

set -e

if [ "$#" != 1 ]; then
    echo "Expected one argument"
    exit 1
fi

CLUSTER_CONF_DIR=$(pwd)/cluster-config

# Variables for master and minion nodes.
DASHBOARD_MEMORY=${DASHBOARD_MEMORY:-2048}
MASTER_MEMORY=${MASTER_MEMORY:-2048}
MINIONS_SIZE=${MINIONS_SIZE:-2}
MINION_MEMORY=${MINION_MEMORY:-2048}
FLAVOUR=${FLAVOUR:-"sles"}
DASHBOARD_HOST=${DASHBOARD_HOST:-}
SKIP_DASHBOARD=${SKIP_DASHBOARD:-"false"}
SKIP_ORCHESTRATION=${SKIP_ORCHESTRATION:-"false"}

[ $SKIP_DASHBOARD != "false" ] && SKIP_DASHBOARD="true"
[ $SKIP_ORCHESTRATION != "false" ] && SKIP_ORCHESTRATION="true"

SSH_DEFAULT_ARGS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

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

    if [ "$FLAVOUR" == "opensuse" ]; then
        IMAGE_PATH="${IMAGE_PATH:-$PWD/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2}"
    else
        IMAGE_PATH="${IMAGE_PATH:-$PWD/Base-SLES12-SP2.x86_64-cloud_ext4.qcow2}"
    fi

    if ! [ -f "$IMAGE_PATH" ]; then
        if [ "$FLAVOUR" == "opensuse" ]; then
            echo "[+] Downloading openSUSE qcow2 VM image to '$IMAGE_PATH'"
            wget -O "$IMAGE_PATH" "http://download.opensuse.org/repositories/Virtualization:/containers:/images:/KVM:/Leap:/42.2/images/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2"
        else
            echo "[+] Downloading SLE qcow2 VM image to '$IMAGE_PATH'"
            wget -O "$IMAGE_PATH" "http://download.suse.de/ibs/Devel:/Docker:/Images:/terraform:/SLE-12/images_SLE12_SP2/Base-SLES12-SP2.x86_64-cloud_ext4.qcow2"
        fi
    else
        if [ "$FLAVOUR" == "opensuse" ]; then
            echo "[*] Already downloaded openSUSE qcow2 VM image to '$IMAGE_PATH'"
        else
            echo "[*] Already downloaded SLE qcow2 VM image to '$IMAGE_PATH'"
        fi
    fi

    # Make sure that libvirt is started.
    # While this probably shouldn't be in this script, meh.
    sudo systemctl start libvirtd.service virtlogd.socket virtlockd.socket || :
fi

[ -n "$TF_DEBUG" ] && export TF_LOG=debug

# Go kubes go!
./k8s-setup \
    --verbose \
    -F libvirt-obs.profile \
    -V salt_dir="$SALT_PATH" \
    -V cluster_prefix=$prefix \
    -V skip_dashboard=$SKIP_DASHBOARD \
    -V dashboard_memory=$DASHBOARD_MEMORY \
    -V master_memory=$MASTER_MEMORY \
    -V kube_minions_size=$MINIONS_SIZE \
    -V minion_memory=$MINION_MEMORY \
    -V volume_source="$IMAGE_PATH" \
    -V dashboard_host=$DASHBOARD_HOST \
    -V skip_role_assignments=$SKIP_ORCHESTRATION \
    $1

if [ "$1" != "apply" ]; then
    exit $?
fi

notify-send "The infrastructure is up, running Salt!"

if [ $SKIP_ORCHESTRATION == "false" ] && [ $SKIP_DASHBOARD == "false" ]; then
    ssh -i ssh/id_docker \
        $SSH_DEFAULT_ARGS \
        root@`terraform output ip_dashboard` \
        bash /tmp/provision-dashboard.sh --finish

    scp -i ssh/id_docker \
        $SSH_DEFAULT_ARGS \
        root@`terraform output ip_dashboard`:admin.tar $CLUSTER_CONF_DIR

    tar xvpf $CLUSTER_CONF_DIR/admin.tar -C $CLUSTER_CONF_DIR

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
