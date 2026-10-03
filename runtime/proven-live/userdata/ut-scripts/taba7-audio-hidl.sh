#!/bin/sh
set +e

LOG="/userdata/ut-logs/taba7-audio-hidl.log"
mkdir -p /userdata/ut-logs /userdata/ut-scripts
exec >>"$LOG" 2>&1

echo
echo "===== TABA7 AUDIO HIDL START $(date) ====="

UIDP="$(id -u phablet 2>/dev/null || echo 32011)"
RT="/run/user/$UIDP"
BUS="unix:path=$RT/bus"

echo "UIDP=$UIDP"
echo "RT=$RT"

echo "===== WAIT FOR ANDROID LXC ====="
i=0
while [ "$i" -lt 90 ]; do
  if lxc-info -n android 2>/dev/null | grep -q "State:.*RUNNING"; then
    echo "ANDROID_LXC_RUNNING=yes"
    break
  fi
  i=$((i + 1))
  sleep 1
done

if ! lxc-info -n android 2>/dev/null | grep -q "State:.*RUNNING"; then
  echo "ANDROID_LXC_RUNNING=no"
  exit 0
fi

echo "===== WAIT FOR PHABLET USER BUS ====="
i=0
while [ "$i" -lt 90 ]; do
  [ -S "$RT/bus" ] && break
  i=$((i + 1))
  sleep 1
done

if [ ! -S "$RT/bus" ]; then
  echo "PHABLET_BUS_READY=no"
  exit 0
fi

echo "PHABLET_BUS_READY=yes"

SRC_HOST="/system/lib64/hw/audio.hidl_compat.default.so"
DST_HOST="/vendor/lib64/hw/audio.primary.default.so"
SRC_ANDROID="/android/system/lib64/hw/audio.hidl_compat.default.so"
DST_ANDROID="/android/vendor/lib64/hw/audio.primary.default.so"

bind_if_needed() {
  SRC="$1"
  DST="$2"

  echo "CHECK_BIND_SRC=$SRC"
  echo "CHECK_BIND_DST=$DST"

  if [ ! -f "$SRC" ] || [ ! -f "$DST" ]; then
    echo "BIND_SKIP_MISSING_FILE"
    return 0
  fi

  SRC_SHA="$(sha256sum "$SRC" 2>/dev/null | awk '{print $1}')"
  DST_SHA="$(sha256sum "$DST" 2>/dev/null | awk '{print $1}')"

  echo "SRC_SHA=$SRC_SHA"
  echo "DST_SHA_BEFORE=$DST_SHA"

  if [ "$SRC_SHA" != "$DST_SHA" ]; then
    mount -o bind "$SRC" "$DST"
    echo "BIND_RC=$?"
  else
    echo "BIND_ALREADY_ACTIVE_OR_PERSISTENT=yes"
  fi

  sha256sum "$DST" 2>/dev/null || true
}

echo "===== BIND HIDL WRAPPER OVER 64-BIT AUDIO STUB ====="
bind_if_needed "$SRC_HOST" "$DST_HOST"
bind_if_needed "$SRC_ANDROID" "$DST_ANDROID"

echo "===== START ANDROID AUDIO HAL IF NEEDED ====="
if lxc-attach -n android -- /system/bin/toybox pgrep -f "android.hardware.audio.service" >/dev/null 2>&1; then
  echo "ANDROID_AUDIO_HAL_ALREADY_RUNNING=yes"
else
  nohup lxc-attach -n android -- /vendor/bin/hw/android.hardware.audio.service >>"$LOG" 2>&1 &
  echo "ANDROID_AUDIO_HAL_START_PID=$!"
  sleep 3
fi

echo "===== AUDIO HAL PROCESS CHECK ====="
ps -ef | grep -Ei "android.hardware.audio.service" | grep -v grep || true

echo "===== AUDIO HAL LSHAL CHECK ====="
lxc-attach -n android -- /system/bin/lshal 2>/dev/null | grep -Ei "audio|soundtrigger" || true

echo "===== RESET NORMAL USER PULSE ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" \
  systemctl --user stop pulseaudio.service pulseaudio.socket 2>/dev/null || true

pkill -u phablet pulseaudio 2>/dev/null || true
rm -f "$RT/pulse/pid" "$RT/pulse/native" 2>/dev/null || true

runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" \
  systemctl --user reset-failed pulseaudio.service pulseaudio.socket audiosystem-passthrough-af.service audiosystem-passthrough-qti.service 2>/dev/null || true

runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" \
  systemctl --user start pulseaudio.socket pulseaudio.service

echo "PULSE_START_RC=$?"
sleep 5

echo "===== SET DEFAULT SINK ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-default-sink sink.primary-out 2>/dev/null || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-sink-mute sink.primary-out false 2>/dev/null || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-sink-volume sink.primary-out 35% 2>/dev/null || true

echo "===== FINAL PULSE STATE ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl info 2>&1 || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl list short sinks 2>&1 || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl list short sources 2>&1 || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl list short cards 2>&1 || true

echo "===== TABA7 AUDIO HIDL DONE $(date) ====="
exit 0
