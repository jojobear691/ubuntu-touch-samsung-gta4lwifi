#!/bin/sh
set -eu

case "${1:-start}" in
  start)
    mountpoint -q /usr/bin/media-hub-server || \
      mount --bind /home/phablet/media-hub-server.patched /usr/bin/media-hub-server

    mountpoint -q /etc/apparmor.d/usr.bin.media-hub-server || \
      mount --bind /home/phablet/usr.bin.media-hub-server.patched /etc/apparmor.d/usr.bin.media-hub-server

    apparmor_parser -r /etc/apparmor.d/usr.bin.media-hub-server
    ;;

  stop)
    mountpoint -q /usr/bin/media-hub-server && \
      umount /usr/bin/media-hub-server || true

    mountpoint -q /etc/apparmor.d/usr.bin.media-hub-server && \
      umount /etc/apparmor.d/usr.bin.media-hub-server || true
    ;;

  *)
    echo "usage: $0 {start|stop}" >&2
    exit 2
    ;;
esac
