#!/bin/bash
set +e

LOGDIR="/userdata/ut-tests"
mkdir -p "$LOGDIR" 2>/dev/null || true
LOG="$LOGDIR/taba7-wlan-on.log"

exec > >(tee -a "$LOG") 2>&1

echo
echo "===== taba7-wlan-on run ====="
date
uptime

echo
echo "===== PRE STATE ====="
nmcli general status 2>&1 || true
nmcli device status 2>&1 || true
iw dev wlan0 link 2>&1 || true

if iw dev wlan0 link 2>/dev/null | grep -q "Connected to"; then
  echo "RESULT=already_connected_no_wlan_poke_needed"
  exit 0
fi

echo
echo "===== WAIT FOR ANDROID WIFI HELPER STACK ====="
for i in $(seq 1 90); do
  PCTL="$(lxc-attach -n android --clear-env -- /system/bin/getprop sys.powerctl 2>/dev/null || true)"
  CNSS="$(lxc-attach -n android --clear-env -- /system/bin/getprop init.svc.cnss-daemon 2>/dev/null || true)"
  WHAL="$(lxc-attach -n android --clear-env -- /system/bin/getprop init.svc.vendor.wifi_hal_legacy 2>/dev/null || true)"

  if [ -n "$PCTL" ]; then
    echo "sys.powerctl is not blank: $PCTL"
    echo "RESULT=refuse_during_powerctl"
    exit 1
  fi

  echo "wait=$i cnss=$CNSS wifi_hal=$WHAL"

  if [ "$CNSS" = "running" ] && [ "$WHAL" = "running" ]; then
    break
  fi

  sleep 1
done

echo
echo "===== WAIT FOR /dev/wlan ====="
for i in $(seq 1 60); do
  if [ -e /dev/wlan ]; then
    echo "/dev/wlan present at wait=$i"
    break
  fi
  sleep 1
done

if [ ! -e /dev/wlan ]; then
  echo "RESULT=fail_no_dev_wlan"
  exit 1
fi

echo
echo "===== SET FWPATH ====="
if [ -w /sys/module/wlan/parameters/fwpath ]; then
  printf sta > /sys/module/wlan/parameters/fwpath
  echo "FWPATH_RC=$?"
  echo "FWPATH_NOW=$(cat /sys/module/wlan/parameters/fwpath 2>/dev/null || true)"
else
  echo "FWPATH_PATH_NOT_WRITABLE_OR_MISSING"
fi

echo
echo "===== WLAN ON IF NEEDED ====="
if ip link show wlan0 >/dev/null 2>&1; then
  echo "wlan0 already exists, not writing ON again"
else
  timeout 20 sh -c 'printf ON > /dev/wlan'
  WLAN_ON_RC=$?
  echo "WLAN_ON_RC=$WLAN_ON_RC"
fi

echo
echo "===== WAIT FOR WLAN0 ====="
for i in $(seq 1 60); do
  if ip link show wlan0 >/dev/null 2>&1; then
    echo "wlan0 present at wait=$i"
    break
  fi
  sleep 1
done

if ! ip link show wlan0 >/dev/null 2>&1; then
  echo "RESULT=fail_no_wlan0_after_on"
  exit 1
fi

echo
echo "===== NETWORKMANAGER RECONNECT ====="
nmcli radio wifi on 2>&1 || true
nmcli device set wlan0 managed yes 2>&1 || true
nmcli connection modify taba7-wlan0-manual-v2 connection.autoconnect yes connection.autoconnect-priority 50 2>&1 || true

if iw dev wlan0 link 2>/dev/null | grep -q "Connected to"; then
  echo "Already connected after wlan0 appeared"
else
  nmcli connection up taba7-wlan0-manual-v2 ifname wlan0 2>&1 || true
fi

sleep 5

echo
echo "===== POST STATE ====="
nmcli general status 2>&1 || true
nmcli device status 2>&1 || true
iw dev wlan0 link 2>&1 || true
ip addr show wlan0 2>&1 || true
ip route 2>&1 || true

echo
echo "RESULT=taba7_wlan_on_done"
exit 0
