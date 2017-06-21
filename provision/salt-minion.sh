#!/bin/sh

log()   { echo ">>> $1" ; }
warn()  { log "WARNING: $1" ; }
abort() { log "FATAL: $1" ; exit 1 ; }

MANIFESTS_DIR=/etc/kubernetes/manifests
DASHBOARD_HOST=
ROLES=

# global args for running zypper
ZYPPER_GLOBAL_ARGS="-n --no-gpg-checks --quiet --no-color"

while [ $# -gt 0 ] ; do
  case $1 in
    --debug)
      set -x
      ;;
    -d|--dashboard)
      DASHBOARD_HOST=$2
      shift
      ;;
    -R|--role)
      ROLES="$ROLES $2"
      shift
      ;;
    *)
      abort "Unknown argument $1"
      ;;
  esac
  shift
done

###################################################################

service_exist()   { systemctl list-unit-files | grep -q "$1.service" &> /dev/null ; }
service_running() { systemctl status $1 | grep -q running &> /dev/null ; }

set_salt_master() {
    log "Setting Salt master to $1"
    echo "master: $1" > "/etc/salt/minion.d/minion.conf"
    echo "grains_refresh_every: 10" > "/etc/salt/minion.d/grains_refresh.conf"
}

set_roles() {
  log "Setting roles: $@"
  echo "roles:" > /etc/salt/grains
  for g in $@ ; do
    echo "- $g" >> /etc/salt/grains
  done
}

###################################################################

source /etc/os-release

log "Fixing the ssh keys permissions and setting the authorized keys"
chmod 600 /root/.ssh/*
cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

case $NAME in
  "CAASP")
    # do not try to install anything in CaaSP hosts
    ;;
  *)
    log "Installing the Salt minion"
    zypper $ZYPPER_GLOBAL_ARGS in --force-resolution --no-recommends salt-minion
    [ $? -eq 0 ] || abort "could not install Salt minion"
    ;;
esac

if [ -n "$DASHBOARD_IP" ] ; then
    log "Hardcoding dashboard IP"
    echo "$DASHBOARD_IP dashboard $DASHBOARD_HOST" >> /etc/hosts
fi

# set the Salt master
if   [ -n "$DASHBOARD_HOST" ] ; then set_salt_master "$DASHBOARD_HOST"
elif [ -n "$DASHBOARD_IP"   ] ; then set_salt_master "$DASHBOARD_IP"
else                                 set_salt_master "dashboard"
fi

# ... the grains
[ -n "$ROLES" ] && set_roles $ROLES

case $NAME in
  "CAASP")
    # Start container-feeder only in caasp.
    log "Starting the container-feeder"
    systemctl start "container-feeder"  || abort "could not start the container-feeder"
    systemctl enable "container-feeder" || abort "could not enable the container-feeder service"
    ;;
esac

if ls $MANIFESTS_DIR/* &> /dev/null ; then
  if service_exist "kubelet" ; then
    log "Enabling & (re)starting the Kubelet"
    systemctl restart "kubelet" || abort "could not restart the kubelet"
    systemctl enable "kubelet"  || abort "could not enable the kubelet service"
  else
    warn "kubelet not installed and manifests found"
  fi
fi

log "Enabling & (re)starting the Salt minion"
systemctl enable salt-minion   || abort "could not enable the Salt minion"
systemctl restart salt-minion  || abort "could not restart the Salt minion"
sleep 2
log "Salt minion status:"
log "------------------------------"
systemctl status -l salt-minion || abort "salt minion is not running"
log "------------------------------"
