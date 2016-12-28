#!/bin/sh

log()   { echo ">>> $1" ; }
warn()  { log "WARNING: $1" ; }
abort() { log "FATAL: $1" ; exit 1 ; }

SKIP_ROLE_ASSIGNMENTS=
TMP_SALT_ROOT=/tmp/salt

# global args for running zypper
ZYPPER_GLOBAL_ARGS="-n --no-gpg-checks --quiet --no-color"

while [ $# -gt 0 ] ; do
  case $1 in
    --debug)
      set -x
      ;;
    -m|--salt-master)
      SALT_MASTER=$2
      shift
      ;;
    --tmp-salt-root)
      TMP_SALT_ROOT=$2
      shift
      ;;
    --skip-role-assignments)
      SKIP_ROLE_ASSIGNMENTS=1
      shift
      ;;
    *)
      abort "Unknown argument $1"
      ;;
  esac
  shift
done

###################################################################

log "Fixing the ssh keys permissions and setting the authorized keys"
chmod 600 /root/.ssh/*
cp -f /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

log "Installing the Salt minion"
zypper $ZYPPER_GLOBAL_ARGS in --force-resolution --no-recommends salt-minion
[ $? -eq 0 ] || abort "could not install Salt minion"

if [ -n "$SALT_MASTER" ] ; then
    log "Setting salt master: $SALT_MASTER"
    echo "master: $SALT_MASTER" > "$TMP_SALT_ROOT/config/minion.d/minion.conf"
else
    warn "no salt master set!"
fi

[ -f "$TMP_SALT_ROOT/config/minion.d/minion.conf" ] || warn "no minon.conf file!"

log "Copying the Salt config"
mkdir -p /etc/salt/minion.d
cp -v $TMP_SALT_ROOT/config/minion.d/*  /etc/salt/minion.d
[ -z $SKIP_ROLE_ASSIGNMENTS ] && cp -v $TMP_SALT_ROOT/grains /etc/salt/

log "Enabling & starting the Salt minion"
systemctl enable salt-minion || abort "could not enable Salt minion"
systemctl start salt-minion  || abort "could not start Salt minion"

log "Salt minion config file:"
log "------------------------------"
cat /etc/salt/minion.d/minion.conf || abort "no salt minion configuration"
log "------------------------------"
sleep 2
log "Salt minion status:"
log "------------------------------"
systemctl status -l salt-minion || abort "salt minion is not running"
log "------------------------------"
