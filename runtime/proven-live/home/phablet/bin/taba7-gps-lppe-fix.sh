#!/bin/sh
set -eu

for i in $(seq 1 60); do
  if sudo lxc-info -n android 2>/dev/null | grep -q "RUNNING"; then
    if sudo lxc-attach -n android -- sh -c 'test -f /vendor/etc/gps.conf' 2>/dev/null; then
      break
    fi
  fi
  sleep 2
done

sudo lxc-attach -n android -- sh -c '
set -eu
ORIG=/vendor/etc/gps.conf
FIX=/data/local/tmp/gps.conf.taba7-lppe-fixed

umount "$ORIG" 2>/dev/null || true
cp "$ORIG" "$FIX"

set_spaced_kv() {
  key="$1"
  val="$2"
  if grep -Eq "^[#[:space:]]*$key[[:space:]]*=" "$FIX"; then
    sed -i "s|^[#[:space:]]*$key[[:space:]]*=.*|$key = $val|" "$FIX"
  else
    printf "\n%s = %s\n" "$key" "$val" >> "$FIX"
  fi
}

set_spaced_kv LPPE_CP_TECHNOLOGY 0
set_spaced_kv LPPE_UP_TECHNOLOGY 0
set_spaced_kv AGPS_CONFIG_INJECT 1

mount --bind "$FIX" "$ORIG"
setprop ctl.restart gnss_service
sleep 6

echo GNSS_SERVICE=$(getprop init.svc.gnss_service)
grep -Ei "AGPS_CONFIG|LPP_PROFILE|LPPE" "$ORIG" || true
'
