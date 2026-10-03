#!/bin/bash
set +e

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="/userdata/ut-tests/taba7-v10-media-camera-island-run-$STAMP"
mkdir -p "$OUT"

INNER="/data/local/tmp/taba7-v10-media-camera-island-inner.sh"

echo "===== TABA7 V10 MEDIA/CAMERA ISLAND WRAPPER =====" | tee "$OUT/run.txt"
echo "OUT=$OUT" | tee -a "$OUT/run.txt"
date | tee -a "$OUT/run.txt"
echo "boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)" | tee -a "$OUT/run.txt"

echo
echo "===== WAIT FOR ANDROID LXC =====" | tee -a "$OUT/run.txt"
ANDROID_READY=NO
for i in $(seq 1 90); do
  if lxc-info -n android 2>/dev/null | grep -q "RUNNING"; then
    if lxc-attach -n android -- /system/bin/sh -c 'echo android-shell-ready' 2>/dev/null | grep -q android-shell-ready; then
      ANDROID_READY=YES
      echo "ANDROID_READY_AT=$i" | tee -a "$OUT/run.txt"
      break
    fi
  fi
  sleep 2
done

if [ "$ANDROID_READY" != "YES" ]; then
  echo "RESULT=ANDROID_NOT_READY" | tee -a "$OUT/run.txt"
  exit 1
fi

echo
echo "===== RUN INNER SCRIPT =====" | tee -a "$OUT/run.txt"
lxc-attach -n android -- /system/bin/sh "$INNER" 2>&1 | tee "$OUT/inner-run.txt"
INNER_RC="${PIPESTATUS[0]}"
echo "INNER_RC=$INNER_RC" | tee -a "$OUT/run.txt"

echo
echo "===== HOST AUDIO PROOF =====" | tee "$OUT/audio-proof.txt"
PH_UID="$(id -u phablet 2>/dev/null || echo 32011)"
{
  echo "phablet_uid=$PH_UID"
  runuser -u phablet -- sh -c "XDG_RUNTIME_DIR=/run/user/$PH_UID pactl info" 2>&1 || true
  echo
  runuser -u phablet -- sh -c "XDG_RUNTIME_DIR=/run/user/$PH_UID pactl list short sinks" 2>&1 || true
  echo
  runuser -u phablet -- sh -c "XDG_RUNTIME_DIR=/run/user/$PH_UID pactl list short sink-inputs" 2>&1 || true
} | tee -a "$OUT/audio-proof.txt"

echo
echo "===== CLASSIFIER =====" | tee "$OUT/classifier.txt"

if lxc-attach -n android -- /system/bin/getprop sys.powerctl 2>/dev/null | grep -q .; then
  echo "SYS_POWERCTL_SET=YES" | tee -a "$OUT/classifier.txt"
else
  echo "SYS_POWERCTL_SET=NO" | tee -a "$OUT/classifier.txt"
fi

if [ "$(lxc-attach -n android -- /system/bin/sha256sum /system/lib64/libcameraservice.so 2>/dev/null | awk '{print $1}')" = "6592667490431d1d3fbfe670fa1538b6c690b83303d53cc45f108a5e00afc0cd" ]; then
  echo "PATCHED_LIBCAMERASERVICE_VISIBLE=YES" | tee -a "$OUT/classifier.txt"
else
  echo "PATCHED_LIBCAMERASERVICE_VISIBLE=NO" | tee -a "$OUT/classifier.txt"
fi

if lxc-attach -n android -- /system/bin/service check media.camera 2>&1 | grep -q "Service media.camera: found"; then
  echo "MEDIA_CAMERA_FOUND=YES" | tee -a "$OUT/classifier.txt"
else
  echo "MEDIA_CAMERA_FOUND=NO" | tee -a "$OUT/classifier.txt"
fi

if lxc-attach -n android -- /system/bin/service check processinfo 2>&1 | grep -q "Service processinfo: found"; then
  echo "PROCESSINFO_FOUND=YES" | tee -a "$OUT/classifier.txt"
else
  echo "PROCESSINFO_FOUND=NO" | tee -a "$OUT/classifier.txt"
fi

if lxc-attach -n android -- /system/bin/pidof media.swcodec >/dev/null 2>&1; then
  echo "MEDIA_SWCODEC_RUNNING=YES" | tee -a "$OUT/classifier.txt"
else
  echo "MEDIA_SWCODEC_RUNNING=NO" | tee -a "$OUT/classifier.txt"
fi

if lxc-attach -n android -- /system/bin/pidof cameraserver-los >/dev/null 2>&1; then
  echo "CAMERASERVER_LOS_RUNNING=YES" | tee -a "$OUT/classifier.txt"
else
  echo "CAMERASERVER_LOS_RUNNING=NO" | tee -a "$OUT/classifier.txt"
fi

if lxc-attach -n android -- /system/bin/pidof ut_camera_binder_stubs_grant_v10 >/dev/null 2>&1; then
  echo "BINDER_STUBS_V10_RUNNING=YES" | tee -a "$OUT/classifier.txt"
else
  echo "BINDER_STUBS_V10_RUNNING=NO" | tee -a "$OUT/classifier.txt"
fi

lxc-attach -n android -- /system/bin/dumpsys media.camera 2>/dev/null > "$OUT/dumpsys-media-camera.txt"

if grep -q 'Device 0 maps to "0"' "$OUT/dumpsys-media-camera.txt"; then
  echo "DEVICE_0_MAPPED=YES" | tee -a "$OUT/classifier.txt"
else
  echo "DEVICE_0_MAPPED=NO" | tee -a "$OUT/classifier.txt"
fi

if grep -q 'Device 1 maps to "1"' "$OUT/dumpsys-media-camera.txt"; then
  echo "DEVICE_1_MAPPED=YES" | tee -a "$OUT/classifier.txt"
else
  echo "DEVICE_1_MAPPED=NO" | tee -a "$OUT/classifier.txt"
fi

if grep -q "Allowed user IDs: 0" "$OUT/dumpsys-media-camera.txt"; then
  echo "ALLOWED_USER_0=YES" | tee -a "$OUT/classifier.txt"
else
  echo "ALLOWED_USER_0=NO" | tee -a "$OUT/classifier.txt"
fi

if runuser -u phablet -- sh -c "XDG_RUNTIME_DIR=/run/user/$PH_UID pactl list short sinks" 2>/dev/null | grep -q "sink.primary-out"; then
  echo "PULSE_PRIMARY_SINK_PRESENT=YES" | tee -a "$OUT/classifier.txt"
else
  echo "PULSE_PRIMARY_SINK_PRESENT=NO" | tee -a "$OUT/classifier.txt"
fi

echo
echo "===== TAR OUTPUT =====" | tee -a "$OUT/run.txt"
tar -C /userdata/ut-tests -czf "$OUT.tar.gz" "$(basename "$OUT")"
sha256sum "$OUT.tar.gz" | tee -a "$OUT/run.txt"

echo
echo "===== SUMMARY ====="
echo "OUT=$OUT"
echo "TAR=$OUT.tar.gz"
cat "$OUT/classifier.txt"

if grep -q "MEDIA_CAMERA_FOUND=YES" "$OUT/classifier.txt" && \
   grep -q "PROCESSINFO_FOUND=YES" "$OUT/classifier.txt" && \
   grep -q "MEDIA_SWCODEC_RUNNING=YES" "$OUT/classifier.txt" && \
   grep -q "CAMERASERVER_LOS_RUNNING=YES" "$OUT/classifier.txt" && \
   grep -q "BINDER_STUBS_V10_RUNNING=YES" "$OUT/classifier.txt" && \
   grep -q "ALLOWED_USER_0=YES" "$OUT/classifier.txt" && \
   grep -q "PULSE_PRIMARY_SINK_PRESENT=YES" "$OUT/classifier.txt"; then
  echo "RESULT=TABA7_V10_MEDIA_CAMERA_ISLAND_OK"
  exit 0
else
  echo "RESULT=TABA7_V10_MEDIA_CAMERA_ISLAND_NEEDS_REVIEW"
  exit 2
fi
