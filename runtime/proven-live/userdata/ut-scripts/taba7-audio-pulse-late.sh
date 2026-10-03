#!/bin/sh
set +e
LOG="/userdata/ut-logs/taba7-audio-pulse-late.log"
mkdir -p /userdata/ut-logs
exec >>"$LOG" 2>&1

echo
echo "===== TABA7 AUDIO PULSE LATE $(date) ====="

UIDP="$(id -u phablet 2>/dev/null || echo 32011)"
RT="/run/user/$UIDP"
BUS="unix:path=$RT/bus"

echo "UIDP=$UIDP"
echo "RT=$RT"

i=0
while [ "$i" -lt 90 ]; do
  [ -S "$RT/bus" ] && break
  i=$((i+1))
  sleep 1
done

if [ ! -S "$RT/bus" ]; then
  echo "PHABLET_BUS_READY=no"
  exit 0
fi

echo "PHABLET_BUS_READY=yes"

i=0
while [ "$i" -lt 60 ]; do
  lxc-attach -n android -- /system/bin/lshal 2>/dev/null | grep -q "android.hardware.audio@6.0::IDevicesFactory/default" && break
  i=$((i+1))
  sleep 1
done

echo "===== AUDIO HAL REGISTRATION ====="
lxc-attach -n android -- /system/bin/lshal 2>/dev/null | grep -Ei "audio|soundtrigger" || true

echo "===== CLEAN USER PULSE ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" \
  systemctl --user stop pulseaudio.service pulseaudio.socket audiosystem-passthrough-af.service audiosystem-passthrough-qti.service 2>/dev/null || true

pkill -u phablet pulseaudio 2>/dev/null || true
rm -f "$RT/pulse/pid" "$RT/pulse/native" 2>/dev/null || true
mkdir -p "$RT/pulse"
chown -R phablet:phablet "$RT/pulse"

runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" \
  systemctl --user reset-failed pulseaudio.service pulseaudio.socket audiosystem-passthrough-af.service audiosystem-passthrough-qti.service 2>/dev/null || true

echo "===== START NORMAL USER PULSE ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" \
  systemctl --user start pulseaudio.socket pulseaudio.service
echo "PULSE_START_RC=$?"

sleep 6

echo "===== SET DEFAULT SINK ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-default-sink sink.primary-out 2>/dev/null || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-sink-mute sink.primary-out false 2>/dev/null || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-sink-volume sink.primary-out 35% 2>/dev/null || true

echo "===== FINAL PULSE STATE ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl info 2>&1 || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl list short sinks 2>&1 || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl list short cards 2>&1 || true

echo "===== PROCESS STATE ====="
ps -ef | grep -Ei "pulseaudio|android.hardware.audio.service|audiosystem-passthrough" | grep -v grep || true
echo "===== TABA7 AUDIO PULSE LATE DONE $(date) ====="
exit 0
