#!/bin/bash
set +e

LOG="/userdata/ut-tests/taba7-hide-extra-wifi.log"
mkdir -p /userdata/ut-tests 2>/dev/null || true
exec > >(tee -a "$LOG") 2>&1

echo
echo "===== taba7-hide-extra-wifi run ====="
date
uptime

echo
echo "===== WAIT FOR NETWORKMANAGER DEVICES ====="
for i in $(seq 1 90); do
  SEEN="$(nmcli -t -f DEVICE device status 2>/dev/null | grep -E "^(swlan0|p2p-dev-wlan0|p2p-dev-swlan0)$" | wc -l)"
  echo "wait=$i seen_extra_devices=$SEEN"

  if [ "$SEEN" -ge 1 ]; then
    break
  fi

  sleep 1
done

echo
echo "===== BEFORE ====="
nmcli device status 2>&1 || true
iw dev wlan0 link 2>&1 || true

echo
echo "===== SET EXTRA DEVICES UNMANAGED ONLY ====="
for d in swlan0 p2p-dev-wlan0 p2p-dev-swlan0; do
  echo "--- $d ---"
  nmcli device set "$d" managed no 2>&1 || true
done

sleep 3

echo
echo "===== AFTER ====="
nmcli device status 2>&1 || true

echo
echo "===== VERIFY WLAN0 STILL OK ====="
nmcli general status 2>&1 || true
iw dev wlan0 link 2>&1 || true
ip addr show wlan0 2>&1 || true

echo
echo "RESULT=taba7_hide_extra_wifi_done"
exit 0
