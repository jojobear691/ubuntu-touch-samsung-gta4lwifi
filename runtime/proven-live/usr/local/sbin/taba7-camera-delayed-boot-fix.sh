#!/bin/sh
set +e

HOST_FILE="/android/data/local/tmp/libcameraservice-real-trust-agent-photo-fixed-clean-20260620.so"
ANDROID_FILE="/data/local/tmp/libcameraservice-real-trust-agent-photo-fixed-clean-20260620.so"
EXPECTED="389eaa4d3312befd4f1054905a63e5883b13c072f3e3668a642c02178d99f3eb"
RESCUE_SCRIPT="/userdata/ut-scripts/taba7-camera-black-screen-rescue.sh"

LOG="/userdata/ut-tests/taba7-camera-delayed-boot-fix-last.log"
mkdir -p /userdata/ut-tests

{
echo "=== TABA7 CAMERA DELAYED BOOT FIX START $(date) ==="

echo
echo "=== VERIFY CLEAN PHOTO LIB ==="
ls -l "$HOST_FILE" 2>/dev/null || true
HOST_HASH="$(sha256sum "$HOST_FILE" 2>/dev/null | awk '{print $1}')"
echo "host_clean_lib_hash=$HOST_HASH"

if [ "$HOST_HASH" != "$EXPECTED" ]; then
  echo "ERROR: clean fixed libcameraservice missing or wrong hash"
  exit 0
fi

echo
echo "=== VERIFY REAL RESCUE SCRIPT ==="
ls -l "$RESCUE_SCRIPT" 2>/dev/null || true
if [ ! -f "$RESCUE_SCRIPT" ]; then
  echo "ERROR: real black-screen rescue script missing"
  exit 0
fi
chmod +x "$RESCUE_SCRIPT" 2>/dev/null || true

echo
echo "=== WAIT FOR ANDROID PATHS ==="
for i in $(seq 1 60); do
  lxc-attach -n android -- /system/bin/sh -c '/system/bin/test -e /system/lib64/libcameraservice.so' >/dev/null 2>&1 && break
  /bin/sleep 1
done

echo
echo "=== BIND CLEAN PHOTO FIX LIB ==="
lxc-attach -n android -- /system/bin/sh -c "
/system/bin/mount -o bind '$ANDROID_FILE' /system/lib64/libcameraservice.so
/system/bin/sha256sum /system/lib64/libcameraservice.so
" 2>&1

echo
echo "=== KILL ALL CAMERASERVER-LOS ==="
lxc-attach -n android -- /system/bin/sh -c '
PIDS="$(/system/bin/pidof cameraserver-los 2>/dev/null)"
echo "FOUND_PIDS=$PIDS"

for p in $PIDS; do
  echo "TERM $p"
  /system/bin/kill -TERM "$p" 2>/dev/null || true
done

/system/bin/sleep 3

PIDS="$(/system/bin/pidof cameraserver-los 2>/dev/null)"
for p in $PIDS; do
  echo "KILL $p"
  /system/bin/kill -KILL "$p" 2>/dev/null || true
done

/system/bin/sleep 2
' 2>&1

echo
echo "=== START EXACTLY ONE CAMERASERVER-LOS ==="
lxc-attach -n android -- /system/bin/sh -c '
/system/bin/nohup /data/local/tmp/cameraserver-los >/dev/null 2>&1 &
/system/bin/sleep 12

PIDS="$(/system/bin/pidof cameraserver-los 2>/dev/null)"
set -- $PIDS
COUNT="$#"

echo "CAMERASERVER_PIDS=$PIDS"
echo "CAMERASERVER_COUNT=$COUNT"
/system/bin/service check media.camera
/system/bin/service list 2>/dev/null | /system/bin/grep -i camera || true
' 2>&1

echo
echo "=== RUN REAL BLACK-SCREEN RESCUE SCRIPT ==="
echo "running_rescue_script=$RESCUE_SCRIPT"
"$RESCUE_SCRIPT" || true
echo "RESCUE_SCRIPT_RAN=YES"

echo
echo "=== FINAL VERIFY ==="
lxc-attach -n android -- /system/bin/sh -c '
/system/bin/sha256sum /system/lib64/libcameraservice.so
/system/bin/pidof cameraserver-los 2>/dev/null
/system/bin/ps -A | /system/bin/grep -E "cameraserver-los|camera.provider|ut_camera" || true
/system/bin/service check media.camera
/system/bin/service list 2>/dev/null | /system/bin/grep -i camera || true
' 2>&1

echo "=== TABA7 CAMERA DELAYED BOOT FIX DONE $(date) ==="
} > "$LOG" 2>&1

cat "$LOG"
exit 0
