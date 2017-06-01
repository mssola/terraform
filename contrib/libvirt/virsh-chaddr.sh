#!/bin/sh
# a utility for changing dynamically the IP address of
# a VM in a DHCP network in libvirt

NETWORK=
HOSTNAME=
NEW_IP=
VIRSH="sudo virsh"

usage() {
cat <<EOF
Usage:

    --network|--net|-n <NET>    DHCP network in libvirt
    --hostname|--host|-h <HOST> the host name
    --ip|--IP|-I|-i <IP>        new IP for the host
    --help|-h                   show this help message

EOF
}

while [ $# -gt 0 ] ; do
  case $1 in
    --network|--net|-n)
	  NETWORK=$2
	  shift
      ;;
    --hostname|--host|-h)
	  HOSTNAME=$2
	  shift
      ;;
    --ip|--IP|-I|-i)
	  NEW_IP=$2
	  shift
      ;;
    --help|-h)
	  usage
	  exit 0
      ;;
    *)
      echo "Unknown argument $1"
      usage
      exit 1
      ;;
  esac
  shift
done

###################################################################

if [ -z "$NETWORK" ] ; then
	$VIRSH net-list
	echo "Select the network:"
	read NETWORK
else
	echo "Network: $NETWORK"
fi

if [ -z "$HOSTNAME" ] ; then
	$VIRSH net-dumpxml "$NETWORK" | grep "host"
	echo "Select the hostname:"
	read HOSTNAME
else
	echo "Hostname: $HOSTNAME"
fi

OLD_IP=$($VIRSH net-dumpxml "$NETWORK" | grep "$HOSTNAME" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
if [ -z "$OLD_IP" ] ; then
	echo "Could not find an IP address for $HOSTNAME in"
	$VIRSH net-dumpxml "$NETWORK"
	exit 1
fi
echo "Old IP: $OLD_IP"

if [ -z "$NEW_IP" ] ; then
	echo "New IP?"
	read NEW_IP
else
	echo "New IP: $NEW_IP"
fi

MAC_ADDR=$($VIRSH net-dumpxml "$NETWORK" | grep "$HOSTNAME" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
if [ -z "$MAC_ADDR" ] ; then
	echo "Could not find MAC address for $HOSTNAME in"
	$VIRSH net-dumpxml "$NETWORK" | grep "host"
	exit 1
fi

DEF=$(mktemp)
trap "rm -f $DEF" EXIT
$VIRSH net-dumpxml "$NETWORK" | grep "$HOSTNAME" > $DEF

echo "Removing old entry"
$VIRSH net-update "$NETWORK" delete ip-dhcp-host "$DEF"

echo "Updating $NETWORK network:"
sed -i "s/$OLD_IP/$NEW_IP/g" "$DEF"
$VIRSH net-update "$NETWORK" \
	add-last ip-dhcp-host \
	$DEF \
	--live --config --parent-index 0

echo "New entry committed for $HOSTNAME:"
$VIRSH net-dumpxml "$NETWORK" | grep "$HOSTNAME"
