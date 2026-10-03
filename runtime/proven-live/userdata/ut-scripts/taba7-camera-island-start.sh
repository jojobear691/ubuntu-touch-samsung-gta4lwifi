#!/bin/bash
set +e

LOG="/userdata/ut-tests/taba7-camera-island-start-$(date +%Y%m%d-%H%M%S).log"
mkdir -p /userdata/ut-tests /userdata/android-data/local/tmp
exec > >(tee -a "$LOG") 2>&1

echo "===== TABA7 CAMERA ISLAND START PROCESSFIX ====="
date
echo "LOG=$LOG"

BASE="/data/local/tmp/ut-framework-island/init-zygote-full-framework-artlibs-20260607-130027"
SYSTEM_LIVE="$BASE/system-live"
LINKERCONFIG_LIVE="$BASE/linkerconfig-live"
ART_UPPER="$BASE/art-upper"

STUB="/data/local/tmp/ut_camera_binder_stubs"
CAMERASERVER="/data/local/tmp/cameraserver-los"

APATH='export PATH=/system/bin:/system/xbin:/vendor/bin:/odm/bin:/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/sbin:/bin; set +e;'

A() {
  lxc-attach -n android -- /bin/sh -c "$APATH $1"
}

echo
echo "===== HOST PREFLIGHT ====="
echo "date=$(date)"
echo "lightdm=$(systemctl is-active lightdm 2>&1)"
echo "lxc_android=$(systemctl is-active lxc@android 2>&1)"

echo
echo "===== ANDROID PREFLIGHT ====="
A '
echo "sys.powerctl=$(/system/bin/getprop sys.powerctl 2>/dev/null)"
echo "zygote=$(/system/bin/getprop init.svc.zygote 2>/dev/null)"
echo "media.camera=$(/system/bin/service check media.camera 2>&1)"
echo "processinfo=$(/system/bin/service check processinfo 2>&1)"
echo
echo "--- existing temp processes ---"
ps -A | grep -E "cameraserver-los|ut_camera_binder_stubs|mediaswcodec|zygote64|zygote|app_process64|camera.provider" | grep -v grep || true
echo
echo "--- existing temp mounts ---"
mount 2>/dev/null | grep -E " on /system | on /linkerconfig | on /apex/com.android.art " || true
'

echo
echo "===== REQUIRED FILE CHECK ====="
REQ_OUT="$(A "
for p in \
  '$SYSTEM_LIVE/bin/app_process64' \
  '$SYSTEM_LIVE/bin/app_process64.real' \
  '$SYSTEM_LIVE/framework/framework.jar' \
  '$LINKERCONFIG_LIVE/ld.config.txt' \
  '$ART_UPPER/javalib/core-oj.jar' \
  '$ART_UPPER/javalib/core-libart.jar' \
  '$ART_UPPER/lib64/libnativehelper.so' \
  '$STUB' \
  '$CAMERASERVER'
do
  if [ -e \"\$p\" ]; then
    echo OK=\$p
  else
    echo MISSING=\$p
  fi
done
" 2>&1)"
printf "%s\n" "$REQ_OUT"

if printf "%s\n" "$REQ_OUT" | grep -q "^MISSING="; then
  echo "FATAL: required file missing"
  exit 1
fi

echo
echo "===== BIND LIVE VIEWS ====="
A "
if ! mount | grep -q ' on /system '; then
  mount --bind '$SYSTEM_LIVE' /system
  echo BIND_SYSTEM_RC=\$?
else
  echo BIND_SYSTEM_ALREADY_PRESENT
fi

if ! mount | grep -q ' on /linkerconfig '; then
  mount --bind '$LINKERCONFIG_LIVE' /linkerconfig
  echo BIND_LINKERCONFIG_RC=\$?
else
  echo BIND_LINKERCONFIG_ALREADY_PRESENT
fi

if ! mount | grep -q ' on /apex/com.android.art '; then
  mount --bind '$ART_UPPER' /apex/com.android.art
  echo BIND_ART_RC=\$?
else
  echo BIND_ART_ALREADY_PRESENT
fi

mount 2>/dev/null | grep -E ' on /system | on /linkerconfig | on /apex/com.android.art ' || true
"

echo
echo "===== START ZYGOTE ====="
A '/system/bin/setprop ctl.start zygote 2>&1 || true'

ZYGOTE_PASS=0
STABLE=0
LAST_ZPID=""

for i in $(seq 1 20); do
  LINE="$(A '
zstate="$(/system/bin/getprop init.svc.zygote 2>/dev/null)"
power="$(/system/bin/getprop sys.powerctl 2>/dev/null)"
zpid="$(ps -A | grep -E "zygote64|app_process64.real" | grep -v grep | sed "s/^ *//;s/  */ /g" | cut -d" " -f2 | head -1)"
echo "sys.powerctl=$power zygote=$zstate zpid=$zpid"
ps -A | grep -E "zygote64|app_process64.real" | grep -v grep || true
')"

  ZPID="$(printf "%s\n" "$LINE" | sed -n "s/.*zpid=\([0-9][0-9]*\).*/\1/p" | head -1)"

  echo "--- ZYGOTE_T=$i ---"
  printf "%s\n" "$LINE"

  if [ -n "$ZPID" ] && [ "$ZPID" = "$LAST_ZPID" ] && printf "%s\n" "$LINE" | grep -q "zygote=running" && printf "%s\n" "$LINE" | grep -q "zygote64"; then
    STABLE=$((STABLE + 1))
  elif [ -n "$ZPID" ] && printf "%s\n" "$LINE" | grep -q "zygote=running" && printf "%s\n" "$LINE" | grep -q "zygote64"; then
    LAST_ZPID="$ZPID"
    STABLE=0
  else
    STABLE=0
  fi

  echo "ZYGOTE_STABLE=$STABLE"
  if [ "$STABLE" -ge 4 ]; then
    ZYGOTE_PASS=1
    break
  fi
  sleep 1
done

if [ "$ZYGOTE_PASS" -ne 1 ]; then
  echo "FATAL: zygote not stable"
  exit 1
fi

echo
echo "===== START MEDIASWCODEC BY PROCESS ====="
A '
if ps -A | grep -q "[m]ediaswcodec"; then
  echo MEDIASWCODEC_ALREADY_RUNNING
else
  nohup /apex/com.android.media.swcodec/bin/mediaswcodec >/data/local/tmp/taba7-camera-island-mediaswcodec.log 2>&1 &
  echo MEDIASWCODEC_PID=$!
fi
sleep 2
lshal 2>/dev/null | grep -E "android.hardware.media.c2.*IComponentStore/software" || true
echo "sys.powerctl=$(/system/bin/getprop sys.powerctl 2>/dev/null)"
'

echo
echo "===== START BINDER STUBS BY PROCESS ====="
A "
if ps -A | grep -q '[u]t_camera_binder_stubs'; then
  echo STUB_ALREADY_RUNNING
else
  nohup '$STUB' >/data/local/tmp/taba7-camera-island-binder-stubs.log 2>&1 &
  echo STUB_PID=\$!
fi

sleep 2

/system/bin/service check activity 2>&1 || true
/system/bin/service check activity_task 2>&1 || true
/system/bin/service check appops 2>&1 || true
/system/bin/service check permission 2>&1 || true
/system/bin/service check sensor_privacy 2>&1 || true
/system/bin/service check processinfo 2>&1 || true

echo
echo '--- processinfo raw transaction code 2 ---'
/system/bin/service call processinfo 2 i32 1 i32 \$\$ 2>&1 || true

echo
echo '--- stub process/log ---'
ps -A | grep -E 'ut_camera_binder_stubs' | grep -v grep || true
tail -80 /data/local/tmp/taba7-camera-island-binder-stubs.log 2>/dev/null || true

echo
echo \"sys.powerctl=\$(/system/bin/getprop sys.powerctl 2>/dev/null)\"
"

echo
echo "===== START CAMERASERVER BY PROCESS ====="
A "
if ps -A | grep -q '[c]ameraserver-los'; then
  echo CAMERASERVER_ALREADY_RUNNING
else
  nohup '$CAMERASERVER' >/data/local/tmp/taba7-camera-island-cameraserver.log 2>&1 &
  echo CAMERASERVER_PID=\$!
fi

sleep 2
echo '--- cameraserver process/log ---'
ps -A | grep -E 'cameraserver-los|camera.provider' | grep -v grep || true
tail -80 /data/local/tmp/taba7-camera-island-cameraserver.log 2>/dev/null || true
"

echo
echo "===== WAIT FOR CAMERA SERVICE REAL READY ====="
CAMERA_PASS=0

for i in $(seq 1 60); do
  LINE="$(A '
provider_pid="$(ps -A | grep "android.hardware.camera.provider@2.4-service_64" | grep -v grep | sed "s/^ *//;s/  */ /g" | cut -d" " -f2 | head -1)"
cameraserver_pid="$(ps -A | grep "cameraserver-los" | grep -v grep | sed "s/^ *//;s/  */ /g" | cut -d" " -f2 | head -1)"
stub_pid="$(ps -A | grep "ut_camera_binder_stubs" | grep -v grep | sed "s/^ *//;s/  */ /g" | cut -d" " -f2 | head -1)"
power="$(/system/bin/getprop sys.powerctl 2>/dev/null)"
zyg="$(/system/bin/getprop init.svc.zygote 2>/dev/null)"

media_ok=0
procinfo_ok=0
/system/bin/service check media.camera 2>&1 | grep -E "^Service media.camera: found$" >/dev/null && media_ok=1
/system/bin/service check processinfo 2>&1 | grep -E "^Service processinfo: found$" >/dev/null && procinfo_ok=1

dump="$(/system/bin/dumpsys media.camera 2>/dev/null | grep -E "Number of camera devices|Device [0-9] maps|Allowed user IDs" | head -12)"
dev2=0
map0=0
map1=0
echo "$dump" | grep -q "Number of camera devices: 2" && dev2=1
echo "$dump" | grep -q "Device 0 maps" && map0=1
echo "$dump" | grep -q "Device 1 maps" && map1=1

echo "provider_pid=$provider_pid cameraserver_pid=$cameraserver_pid stub_pid=$stub_pid sys.powerctl=$power zygote=$zyg media_ok=$media_ok processinfo_ok=$procinfo_ok dev2=$dev2 map0=$map0 map1=$map1"
echo "$dump"
')"

  echo "--- CAMERA_WAIT_T=$i ---"
  printf "%s\n" "$LINE"

  if printf "%s\n" "$LINE" | grep -q "media_ok=1" && \
     printf "%s\n" "$LINE" | grep -q "processinfo_ok=1" && \
     printf "%s\n" "$LINE" | grep -q "dev2=1" && \
     printf "%s\n" "$LINE" | grep -q "map0=1" && \
     printf "%s\n" "$LINE" | grep -q "map1=1"; then
    CAMERA_PASS=1
    break
  fi

  sleep 1
done

if [ "$CAMERA_PASS" -ne 1 ]; then
  echo "FATAL: media.camera/processinfo/devices not ready"
  exit 1
fi

echo
echo "===== NOTIFY USER 0 AND 1 ====="
A '
/system/bin/service call media.camera 17 i32 2 i32 1 i32 0 i32 1 2>&1
echo "SERVICE_CALL_RC=$?"
sleep 1
echo "sys.powerctl=$(/system/bin/getprop sys.powerctl 2>/dev/null)"
echo "zygote=$(/system/bin/getprop init.svc.zygote 2>/dev/null)"
/system/bin/service check media.camera 2>&1
/system/bin/service check processinfo 2>&1
/system/bin/dumpsys media.camera 2>&1 | grep -E "Allowed user IDs|USER_SWITCH|Number of camera devices|Device [0-9] maps|Camera error traces" -A5 -B5 || true
'

echo
echo "===== RESTART UT CAMERASERVICE TRUST STORED ====="
echo "--- socket paths before ---"
ls -ld /dev/socket /dev/socket/camera_service /dev/socket/camera_service/camera_service_to_trust 2>&1 || true

su -s /bin/sh phablet -c 'XDG_RUNTIME_DIR=/run/user/32011 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus systemctl --user reset-failed cameraservice-trust-stored.service' 2>&1 || true
su -s /bin/sh phablet -c 'XDG_RUNTIME_DIR=/run/user/32011 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus systemctl --user restart cameraservice-trust-stored.service' 2>&1 || true
sleep 2

echo "--- camera trust service after ---"
su -s /bin/sh phablet -c 'XDG_RUNTIME_DIR=/run/user/32011 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus systemctl --user status cameraservice-trust-stored.service --no-pager' 2>&1 || true

echo "--- socket paths after ---"
ls -ld /dev/socket /dev/socket/camera_service /dev/socket/camera_service/camera_service_to_trust 2>&1 || true
ps auxww | grep -E "camera_service|CameraService|trust-stored|camera-service" | grep -v grep || true

echo
echo "===== FINAL CAMERA ISLAND STATE ====="
echo "lightdm=$(systemctl is-active lightdm 2>&1)"
A '
echo "sys.powerctl=$(/system/bin/getprop sys.powerctl 2>/dev/null)"
echo "zygote=$(/system/bin/getprop init.svc.zygote 2>/dev/null)"
/system/bin/service check media.camera 2>&1 || true
/system/bin/service check processinfo 2>&1 || true
ps -A | grep -E "cameraserver-los|ut_camera_binder_stubs|mediaswcodec|zygote64|zygote|app_process64|camera.provider" | grep -v grep || true
/system/bin/dumpsys media.camera 2>&1 | grep -E "Number of camera devices|Device [0-9] maps|Allowed user IDs|Active Camera Clients|Camera error traces" -A4 -B4 || true
'

echo
echo "===== CAMERA ISLAND READY PROCESSFIX ====="
exit 0
