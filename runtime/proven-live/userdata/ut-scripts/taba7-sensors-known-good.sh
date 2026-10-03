#!/usr/bin/env bash
set +e

LOGDIR="/userdata/ut-logs"
LOG="$LOGDIR/taba7-sensors-known-good.log"
mkdir -p "$LOGDIR" /run/taba7-sensors

exec >>"$LOG" 2>&1

echo
echo "===== taba7-sensors-known-good start ====="
date
uptime

echo "===== WAIT FOR ANDROID LXC ====="
for i in $(seq 1 60); do
    if lxc-info -n android 2>/dev/null | grep -q "RUNNING"; then
        echo "android LXC running at wait=$i"
        break
    fi
    sleep 2
done

if ! lxc-info -n android 2>/dev/null | grep -q "RUNNING"; then
    echo "ERROR: android LXC not running"
    exit 1
fi

echo "===== UNMASK SENSORFWD FROM SCRIPT TOO ====="
systemctl unmask sensorfwd.service dbus-com.nokia.SensorService.service 2>/dev/null || true
rm -f /etc/systemd/system/sensorfwd.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

echo "===== PREP SENSOR DIRS INSIDE ANDROID ====="
lxc-attach -n android -- /system/bin/sh -c '
/system/bin/toybox mkdir -p /data/vendor/sensors/scripts 2>/dev/null || true
/system/bin/toybox mkdir -p /mnt/vendor/persist/sensors/registry/registry 2>/dev/null || true
/system/bin/toybox mkdir -p /mnt/vendor/persist/sensors/registry/config 2>/dev/null || true
cp /vendor/etc/sensors/scripts/* /data/vendor/sensors/scripts/ 2>/dev/null || true
chmod -R 0777 /data/vendor/sensors 2>/dev/null || true
' || true

start_sensor_proc() {
    NAME="$1"
    shift

    echo
    echo "===== START $NAME ====="
    lxc-attach -n android -- /system/bin/ps -A 2>/dev/null | grep -F "$NAME" && {
        echo "$NAME already appears to be running"
        return 0
    }

    lxc-attach -n android -- "$@" >>"$LOGDIR/taba7-sensor-$NAME.log" 2>&1 &
    echo "$!" > "/run/taba7-sensors/$NAME.hostpid"
    sleep 2
}

start_sensor_proc "sscrpcd" /vendor/bin/sscrpcd sensorspd
start_sensor_proc "sensors.qti" /vendor/bin/sensors.qti
start_sensor_proc "vendor.qti.hardware.sensorscalibrate@1.0-service" /vendor/bin/hw/vendor.qti.hardware.sensorscalibrate@1.0-service
start_sensor_proc "android.hardware.sensors@2.0-service.multihal" /vendor/bin/hw/android.hardware.sensors@2.0-service.multihal

echo
echo "===== WAIT FOR HIDL SENSOR REGISTRATION ====="
for i in $(seq 1 30); do
    if lxc-attach -n android -- /system/bin/lshal 2>/dev/null | grep -q "android.hardware.sensors@2.0::ISensors/default"; then
        echo "sensors HAL registered at wait=$i"
        break
    fi
    sleep 1
done

echo
echo "===== START HOST SENSORFWD AFTER ANDROID SENSOR HAL ====="
systemctl restart sensorfwd.service 2>/dev/null || true
sleep 2

echo
echo "===== FINAL SENSOR STATUS ====="
systemctl status sensorfwd.service --no-pager -l 2>/dev/null || true
echo
lxc-attach -n android -- /system/bin/ps -A 2>/dev/null | grep -Ei "sensor|ssc|sscrpcd|sensors.qti|multihal|sensorscal" || true
echo
lxc-attach -n android -- /system/bin/lshal 2>/dev/null | grep -Ei "sensor|sensors|sensorscal" || true
echo
printf "sys.powerctl="
lxc-attach -n android -- /system/bin/getprop sys.powerctl 2>/dev/null || true

echo
echo "RESULT=taba7_sensors_known_good_started"

while true; do
    sleep 30
done
