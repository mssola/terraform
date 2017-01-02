#!/bin/sh

log()   { echo ">>> $1" ; }
warn()  { log "WARNING: $1" ; }
abort() { log "FATAL: $1" ; exit 1 ; }

DEBUG=
FINISH=
E2E=
INFRA=cloud
DOCKER_REG_MIRROR=
CONTAINER_START_TIMEOUT=90
SALT_ROOT=/srv
CONFIG_OUT_DIR=/root

# the hostname and port where the API server will be listening at
API_SERVER_DNS_NAME="master"
API_SERVER_PORT=6443

# we will add some pillars in the master...
PILLAR_PARAMS_FILE=$SALT_ROOT/pillar/params.sls

# kubernetes manifests location for the kubelet
K8S_MANIFESTS=/etc/kubernetes/manifests

# global args for running zypper
ZYPPER_GLOBAL_ARGS="-n --no-gpg-checks --quiet --no-color"

# repository information
source /etc/os-release
case $NAME in
  "SLES" )
    CONTAINERS_REPO="http://download.suse.de/ibs/Devel:/Docker/SLE_$(echo -n $VERSION_ID | cut -d. -f1)"
    ;;
  *)
    CONTAINERS_REPO="http://download.opensuse.org/repositories/Virtualization:/containers/$(echo -n $PRETTY_NAME | tr " " "_")"
    ;;
esac

while [ $# -gt 0 ] ; do
  case $1 in
    --debug)
      set -x
      DEBUG=1
      ;;
    -r|--root)
      SALT_ROOT=$2
      shift
      ;;
    -F|--finish)
      FINISH=1
      ;;
    --e2e)
      E2E=1
      ;;
    --config-out-dir)
      CONFIG_OUT_DIR=$2
      shift
      ;;
    --docker-reg-mirror)
      DOCKER_REG_MIRROR=$2
      shift
      ;;
    -i|--infra)
      INFRA=$2
      shift
      ;;
    --extra-api-ip)
      export EXTRA_API_SRV_IP=$2
      shift
      ;;
    --api-server-name)
      API_SERVER_DNS_NAME=$2
      shift
      ;;
    *)
      abort "Unknown argument $1"
      ;;
  esac
  shift
done

###################################################################

add_pillar() {
    log "Pillar: setting $1=\"$2\""
    cat <<-PARAM_SETTING >> "$PILLAR_PARAMS_FILE"

# parameter set by $0
$1: '$2'

PARAM_SETTING
}

wait_for_container() {
  COUNT=0
  until docker ps | grep -v pause | grep $1 &> /dev/null;
  do
      log "Waiting for $2 container to start"
      [ "$COUNT" -lt "$CONTAINER_START_TIMEOUT" ] || abort "Container $2 didn't start, giving up..."
      sleep 5
      COUNT=$((COUNT+5))
  done
  log "$2 container is up"
}

if [ -z "$FINISH" ] ; then
    log "Fixing the ssh keys permissions and setting the authorized keys"
    chmod 600 /root/.ssh/*
    cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

    log "Adding containers repository"
    zypper $ZYPPER_GLOBAL_ARGS ar -Gf $CONTAINERS_REPO containers || abort "could not enable containers repo"

    log "Installing kubernetes-node"
    zypper $ZYPPER_GLOBAL_ARGS in -y kubernetes-node bind-utils || abort "could not install packages"

    # TODO: this would have to be removed
    mkdir -p $K8S_MANIFESTS
    echo "KUBELET_ARGS=\"--config=$K8S_MANIFESTS\"" > /etc/kubernetes/kubelet

    systemctl start {docker,kubelet}.service  || abort "could not start service"
    systemctl enable {docker,kubelet}.service || abort "could not enable service"

    # Wait for containers to be ready
    wait_for_container "salt-master" "salt master"
    wait_for_container "salt-minion-ca" "certificate authority"

    add_pillar infrastructure "$INFRA"
    [ -n "$E2E"               ] && add_pillar e2e true
    [ -n "$DOCKER_REG_MIRROR" ] && add_pillar docker_registry_mirror "$DOCKER_REG_MIRROR"
else
    SALT_MASTER=`docker ps | grep -v pause | grep salt-master | awk '{print $1}'`
    CA_CONTAINER=`docker ps | grep -v pause | grep salt-minion-ca | awk '{print $1}'`

    [ -n "$SALT_MASTER"  ] || abort "could not get salt master container"
    [ -n "$CA_CONTAINER" ] || abort "could not get certificate authority container"

    log "Running orchestration on salt master container ($SALT_MASTER)"
    [ -n "$DEBUG" ] && ORCHESTRATION_FLAGS="-l debug"
    docker exec $SALT_MASTER salt-run $ORCHESTRATION_FLAGS state.orchestrate orch.kubernetes
    [ $? -eq 0 ] || abort "salt-run did not succeed"

    if [ -n "$EXTRA_API_SRV_IP" ] ; then
        API_SERVER_IP=$EXTRA_API_SRV_IP
    else
        API_SERVER_IP=$(host "$API_SERVER_DNS_NAME" | grep "has address" | awk '{print $NF}')
        [ -n "$API_SERVER_IP" ] || abort "could not determine the IP of the API server by resolving $API_SERVER_DNS_NAME: you must provide it with --extra-api-ip"
    fi

    log "Generating a 'kubeconfig' file"
    cat <<EOF > "$CONFIG_OUT_DIR/kubeconfig"
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ca.crt
    server: https://${API_SERVER_IP}:${API_SERVER_PORT}/
  name: default-cluster
contexts:
- context:
    cluster: default-cluster
    user: default-admin
  name: default-system
current-context: default-system
kind: Config
preferences: {}
users:
- name: default-admin
  user:
    client-certificate: admin.crt
    client-key: admin.key
EOF

    log "Creating admin.tar with config files and certificates"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null master:/etc/pki/minion.{crt,key} $CONFIG_OUT_DIR
    [ $? -eq 0 ] || abort "could not copy file from master"

    mv -f $CONFIG_OUT_DIR/minion.crt $CONFIG_OUT_DIR/admin.crt
    mv -f $CONFIG_OUT_DIR/minion.key $CONFIG_OUT_DIR/admin.key

    docker cp $CA_CONTAINER:/etc/pki/ca.crt $CONFIG_OUT_DIR/ca.crt
    [ $? -eq 0 ] || abort "could not copy file from $CA_CONTAINER"

    cd "$CONFIG_OUT_DIR" && tar cvpf admin.tar admin.crt admin.key ca.crt kubeconfig
    [ -f admin.tar ] || abort "admin.tar not generated"

    log "'kubeconfig' file with certificates left at dashboard:$CONFIG_OUT_DIR/admin.tar"
    log "Now you can"
    log "* copy $CONFIG_OUT_DIR/admin.tar to your machine"
    log "* tar -xvpf admin.tar"
    log "* KUBECONFIG=kubeconfig kubectl get nodes"
    log ""
    log "note: we assumed the API server is at https://${API_SERVER_IP}:${API_SERVER_PORT},"
    log "      so check 'kubeconfig' configuration before using it..."
fi

exit 0
