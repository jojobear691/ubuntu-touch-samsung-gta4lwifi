#!/bin/sh
set +e

LOGDIR="/userdata/ut-tests/ui-autostart"
mkdir -p "$LOGDIR" 2>/dev/null || LOGDIR="/tmp"
LOG="$LOGDIR/ut-gta4lwifi-ui-autostart-simple-$(date +%Y%m%d-%H%M%S).log"

exec >>"$LOG" 2>&1

echo "===== UT GTA4LWIFI SIMPLE AUTOSTART ====="
date
uptime
echo "LOG=$LOG"

echo
echo "===== LET BOOT SETTLE ====="
sleep 35

echo
echo "===== WAIT FOR KNOWN-GOOD LOADER ====="
for i in $(seq 1 90); do
  if [ -x /home/phablet/reuse-known-good-ut-ui.sh ]; then
    echo "LOADER_READY_AT=$i"
    break
  fi
  echo "WAIT_LOADER=$i"
  sleep 1
done

if [ ! -x /home/phablet/reuse-known-good-ut-ui.sh ]; then
  echo "ERROR: known-good loader missing"
  ls -lah /home/phablet /userdata/user-data/phablet 2>&1 || true
  exit 0
fi

echo
echo "===== RUN EXACT KNOWN-GOOD LOADER ====="
/home/phablet/reuse-known-good-ut-ui.sh
echo "KNOWN_GOOD_LOADER_RC=$?"

echo
echo "===== FINAL STATE ====="
lxc-info -n android 2>&1 || true
systemctl is-active lightdm.service 2>&1 || true
ls -lah /run/mir_socket /run/wayland-syscomp 2>&1 || true
pgrep -a -f "lomiri|lightdm|lxc-start|spinner" 2>&1 || true

echo
echo "===== LEFT RUNNING ON PURPOSE ====="
exit 0
