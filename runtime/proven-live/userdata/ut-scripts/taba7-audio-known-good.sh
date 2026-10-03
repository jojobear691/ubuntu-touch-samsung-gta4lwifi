#!/bin/sh
set +e

LOG="/userdata/ut-logs/taba7-audio-known-good.log"
mkdir -p /userdata/ut-logs /userdata/ut-audio
exec >>"$LOG" 2>&1

echo
echo "===== TABA7 AUDIO KNOWN GOOD START $(date) ====="

UIDP="$(id -u phablet 2>/dev/null || echo 32011)"
RT="/run/user/$UIDP"
BUS="unix:path=$RT/bus"
PA_CFG="/userdata/ut-audio/pulse-speaker.pa"
PA_LOG="/userdata/ut-logs/taba7-manual-pulseaudio.log"
POL="/userdata/ut-audio/audio_policy_speaker_only.xml"

echo "UIDP=$UIDP"
echo "RT=$RT"

echo "===== WAIT FOR ANDROID LXC ====="
i=0
while [ "$i" -lt 120 ]; do
  lxc-info -n android 2>/dev/null | grep -q "State:.*RUNNING" && break
  i=$((i + 1))
  sleep 1
done
lxc-info -n android 2>&1 || true

echo "===== WAIT FOR PHABLET BUS ====="
i=0
while [ "$i" -lt 120 ]; do
  [ -S "$RT/bus" ] && break
  i=$((i + 1))
  sleep 1
done
[ -S "$RT/bus" ] || { echo "PHABLET_BUS_READY=no"; exit 0; }
echo "PHABLET_BUS_READY=yes"

echo "===== STOP OLD AUTO AUDIO UNITS ====="
systemctl stop taba7-audio-hidl.service taba7-android-audio-hal.service taba7-audio-pulse-late.service 2>/dev/null || true
systemctl reset-failed taba7-audio-hidl.service taba7-android-audio-hal.service taba7-audio-pulse-late.service 2>/dev/null || true

echo "===== STOP USER PULSE SYSTEMD STATE ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" \
  systemctl --user stop pulseaudio.service pulseaudio.socket audiosystem-passthrough-af.service audiosystem-passthrough-qti.service 2>/dev/null || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" \
  systemctl --user reset-failed pulseaudio.service pulseaudio.socket audiosystem-passthrough-af.service audiosystem-passthrough-qti.service 2>/dev/null || true

pkill -u phablet pulseaudio 2>/dev/null || true
rm -f "$RT/pulse/pid" "$RT/pulse/native" 2>/dev/null || true
mkdir -p "$RT/pulse"
chown -R phablet:phablet "$RT/pulse" /userdata/ut-audio /userdata/ut-logs

echo "===== WRITE SPEAKER-ONLY POLICY ====="
cat > "$POL" <<'POLICY'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<audioPolicyConfiguration version="1.0" xmlns:xi="http://www.w3.org/2001/XInclude">
    <globalConfiguration speaker_drc_enabled="true"/>
    <modules>
        <module name="primary" halVersion="3.0">
            <attachedDevices>
                <item>Speaker</item>
                <item>Built-In Mic</item>
            </attachedDevices>
            <defaultOutputDevice>Speaker</defaultOutputDevice>
            <mixPorts>
                <mixPort name="primary-out" role="source" flags="AUDIO_OUTPUT_FLAG_PRIMARY">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT" samplingRates="48000" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
                </mixPort>
                <mixPort name="primary-in" role="sink">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT" samplingRates="48000" channelMasks="AUDIO_CHANNEL_IN_MONO"/>
                </mixPort>
            </mixPorts>
            <devicePorts>
                <devicePort tagName="Speaker" role="sink" type="AUDIO_DEVICE_OUT_SPEAKER">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT" samplingRates="48000" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
                </devicePort>
                <devicePort tagName="Built-In Mic" type="AUDIO_DEVICE_IN_BUILTIN_MIC" role="source">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT" samplingRates="48000" channelMasks="AUDIO_CHANNEL_IN_MONO"/>
                </devicePort>
            </devicePorts>
            <routes>
                <route type="mix" sink="Speaker" sources="primary-out"/>
                <route type="mix" sink="primary-in" sources="Built-In Mic"/>
            </routes>
        </module>
    </modules>
</audioPolicyConfiguration>
POLICY

echo "===== BIND WRAPPER + SPEAKER POLICY ====="
umount /vendor/lib64/hw/audio.primary.default.so 2>/dev/null || true
umount /android/vendor/lib64/hw/audio.primary.default.so 2>/dev/null || true
umount /vendor/etc/audio_policy_configuration.xml 2>/dev/null || true
umount /android/vendor/etc/audio_policy_configuration.xml 2>/dev/null || true

mount -o bind /system/lib64/hw/audio.hidl_compat.default.so /vendor/lib64/hw/audio.primary.default.so
echo "BIND_AUDIO_HOST_RC=$?"
mount -o bind /android/system/lib64/hw/audio.hidl_compat.default.so /android/vendor/lib64/hw/audio.primary.default.so
echo "BIND_AUDIO_ANDROID_RC=$?"
mount -o bind "$POL" /vendor/etc/audio_policy_configuration.xml
echo "BIND_POLICY_HOST_RC=$?"
mount -o bind "$POL" /android/vendor/etc/audio_policy_configuration.xml
echo "BIND_POLICY_ANDROID_RC=$?"

sha256sum /vendor/lib64/hw/audio.primary.default.so /android/vendor/lib64/hw/audio.primary.default.so 2>/dev/null || true
grep -nE "Speaker|Built-In Mic|primary-out|primary-in|fast|bluetooth|wired|earpiece" /vendor/etc/audio_policy_configuration.xml || true

echo "===== START ONE FRESH ANDROID AUDIO HAL ====="
lxc-attach -n android -- /system/bin/toybox pkill -9 -f android.hardware.audio.service 2>/dev/null || true
pkill -9 -f "lxc-attach -n android -- /vendor/bin/hw/android.hardware.audio.service" 2>/dev/null || true
sleep 2

nohup lxc-attach -n android -- /vendor/bin/hw/android.hardware.audio.service >>/userdata/ut-logs/taba7-android-audio-hal.log 2>&1 &
echo "AUDIO_HAL_ATTACH_PID=$!"

i=0
while [ "$i" -lt 30 ]; do
  if lxc-attach -n android -- /system/bin/lshal 2>/dev/null | grep -q "android.hardware.audio@6.0::IDevicesFactory/default"; then
    echo "AUDIO_HAL_REGISTERED=yes"
    break
  fi
  i=$((i + 1))
  sleep 1
done

echo "===== CREATE MANUAL PULSE CONFIG ====="
cat > "$PA_CFG" <<'PA'
load-module module-null-sink sink_name=sink.fake.sco format=s16le rate=8000 channels=1 sink_properties=device.description="Null Output"
load-module module-null-source source_name=source.fake.sco format=s16le rate=8000 channels=1 source_properties=device.description="Null Input"
load-module module-native-protocol-unix
load-module module-dbus-protocol
load-module module-droid-discover voice_virtual_stream=true rate=48000 hidl_args='helper=false'
load-module module-always-sink
set-default-sink sink.primary-out
set-default-source source.primary-in
PA

chown phablet:phablet "$PA_CFG"
: > "$PA_LOG"
chown phablet:phablet "$PA_LOG"

echo "===== START MANUAL PULSE DAEMON ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" HYBRIS_USE_VENDOR_NAMESPACE=1 \
  pulseaudio -nF "$PA_CFG" --daemonize=yes --exit-idle-time=-1 --log-level=debug --log-target=file:"$PA_LOG"
echo "MANUAL_PULSE_START_RC=$?"

echo "===== WAIT FOR PULSE ====="
i=0
while [ "$i" -lt 30 ]; do
  if runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl info >/dev/null 2>&1; then
    echo "PULSE_READY=yes"
    break
  fi
  i=$((i + 1))
  sleep 1
done

echo "===== SET DEFAULT SINK / VOLUME ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-default-sink sink.primary-out 2>/dev/null || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-sink-mute sink.primary-out false 2>/dev/null || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl set-sink-volume sink.primary-out 45% 2>/dev/null || true

echo "===== FINAL STATE ====="
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl info 2>&1 || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl list short sinks 2>&1 || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl list short sources 2>&1 || true
runuser -u phablet -- env XDG_RUNTIME_DIR="$RT" DBUS_SESSION_BUS_ADDRESS="$BUS" pactl list short cards 2>&1 || true

echo "===== PROCESSES ====="
ps -ef | grep -Ei "pulseaudio|android.hardware.audio.service|audiosystem-passthrough" | grep -v grep || true

echo "===== TABA7 AUDIO KNOWN GOOD DONE $(date) ====="
exit 0
