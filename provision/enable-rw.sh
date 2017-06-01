#!/bin/sh

case $1 in
start)
	btrfs property set -ts /.snapshots/1/snapshot ro false
	mount -o remount,rw /
	;;
stop)
	echo "WARN: not implemented yet"
	;;
*)
  abort "Unknown argument $1"
  ;;
esac
