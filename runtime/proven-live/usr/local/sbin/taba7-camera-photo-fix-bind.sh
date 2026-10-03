#!/bin/sh
set +e

HOST_FILE="/android/data/local/tmp/libcameraservice-real-trust-agent-photo-fixed-clean-20260620.so"
ANDROID_FILE="/data/local/tmp/libcameraservice-real-trust-agent-photo-fixed-clean-20260620.so"
EXPECTED="389eaa4d3312befd4f1054905a63e5883b13c072f3e3668a642c02178d99f3eb"

echo "=== TABA7 CAMERA PHOTO FIX BIND START ==="

# Verify the clean fixed lib from the host side because Android /data
# can be slow/quirky during service ordering.
HOST_HASH="$(sha256sum "$HOST_FILE" 2>/dev/null | awk '{print $1}')"
echo "host_clean_lib_hash=$HOST_HASH"

if [ "$HOST_HASH" != "$EXPECTED" ]; then
  echo "ERROR: host clean camera photo fix lib hash mismatch or missing"
  exit 1
fi

# Wait for Android container and Android-side path to exist.
for i in $(seq 1 45); do
  lxc-attach -n android -- /system/bin/sh -c "test -f '$ANDROID_FILE' && test -e /system/lib64/libcameraservice.so" >/dev/null 2>&1 && break
  sleep 1
done

echo "android_file_check:"
lxc-attach -n android -- /system/bin/sh -c "ls -l '$ANDROID_FILE' 2>/dev/null; sha256sum '$ANDROID_FILE' 2>/dev/null" 2>&1

# Bind fixed libcameraservice over Android system lib.
echo "binding clean libcameraservice..."
lxc-attach -n android -- /system/bin/sh -c "
mount -o bind '$ANDROID_FILE' /system/lib64/libcameraservice.so
sha256sum /system/lib64/libcameraservice.so
" 2>&1

# Restart only cameraserver-los so it loads the fixed lib.
echo "restarting cameraserver-los..."
lxc-attach -n android -- /system/bin/sh -c '
PIDS="$(ps -A | awk '"'"'$NF=="cameraserver-los"{print $2}'"'"')"
for p in $PIDS; do kill -TERM "$p" 2>/dev/null || true; done

sleep 3

PIDS="$(ps -A | awk '"'"'$NF=="cameraserver-los"{print $2}'"'"')"
for p in $PIDS; do kill -KILL "$p" 2>/dev/null || true; done

sleep 2

nohup /data/local/tmp/cameraserver-los >/dev/null 2>&1 &

sleep 8

PIDS="$(ps -A | awk '"'"'$NF=="cameraserver-los"{print $2}'"'"')"
COUNT="$(echo "$PIDS" | wc -w)"
echo "CAMERASERVER_PIDS=$PIDS"
echo "CAMERASERVER_COUNT=$COUNT"

service check media.camera
service list | grep -i camera || true
' 2>&1

echo "=== TABA7 CAMERA PHOTO FIX BIND DONE ==="
