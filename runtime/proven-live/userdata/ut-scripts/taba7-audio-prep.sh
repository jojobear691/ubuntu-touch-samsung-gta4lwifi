#!/bin/sh
set +e
LOG="/userdata/ut-logs/taba7-audio-prep.log"
mkdir -p /userdata/ut-logs
exec >>"$LOG" 2>&1

echo
echo "===== TABA7 AUDIO PREP $(date) ====="

i=0
while [ "$i" -lt 90 ]; do
  lxc-info -n android 2>/dev/null | grep -q "State:.*RUNNING" && break
  i=$((i+1))
  sleep 1
done

echo "===== RESTORE STOCK AUDIO POLICY BINDS IF ANY ====="
umount /vendor/etc/audio_policy_configuration.xml 2>/dev/null || true
umount /android/vendor/etc/audio_policy_configuration.xml 2>/dev/null || true

echo "===== BIND HIDL WRAPPER OVER 64-BIT STUB ====="
mount -o bind /system/lib64/hw/audio.hidl_compat.default.so /vendor/lib64/hw/audio.primary.default.so
echo "BIND_HOST_RC=$?"
mount -o bind /android/system/lib64/hw/audio.hidl_compat.default.so /android/vendor/lib64/hw/audio.primary.default.so
echo "BIND_ANDROID_RC=$?"

sha256sum /vendor/lib64/hw/audio.primary.default.so /android/vendor/lib64/hw/audio.primary.default.so 2>/dev/null || true
echo "===== TABA7 AUDIO PREP DONE $(date) ====="
exit 0
