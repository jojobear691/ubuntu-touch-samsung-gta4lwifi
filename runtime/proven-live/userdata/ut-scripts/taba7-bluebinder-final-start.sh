#!/usr/bin/env bash
set +e

STAMP="$(date +%Y%m%d-%H%M%S)"
D="/userdata/ut-tests/final-bluebinder-logs/$STAMP"
mkdir -p "$D"
echo "$D" > /run/taba7-bluebinder-final-last-dir.txt

{
  echo "RESULTDIR=$D"
  echo "DATE=$(date)"
  echo "BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
  echo "UNAME=$(uname -a)"
  echo

  echo "=== DO NOT START IF HCI0 ALREADY EXISTS ==="
  ls -la /sys/class/bluetooth 2>&1 || true
  if [ -d /sys/class/bluetooth/hci0 ]; then
    echo "RESULT=ABORT_HCI0_ALREADY_EXISTS"
    exit 22
  fi

  echo
  echo "=== WAIT FOR ANDROID BLUETOOTH HAL ==="
  HAL_PID=""
  for i in $(seq 1 120); do
    HAL_PID="$(pgrep -f '/vendor/bin/hw/android.hardware.bluetooth@1.0-service-qti' | head -1 || true)"
    if [ -n "$HAL_PID" ] && [ -e "/proc/$HAL_PID/root/dev/ttyHS0" ]; then
      echo "HAL_READY i=$i HAL_PID=$HAL_PID"
      break
    fi
    echo "HAL_WAIT i=$i HAL_PID=${HAL_PID:-NONE}"
    sleep 1
  done

  if [ -z "$HAL_PID" ] || [ ! -e "/proc/$HAL_PID/root/dev/ttyHS0" ]; then
    echo "RESULT=ABORT_HAL_NOT_READY"
    exit 23
  fi

  echo
  echo "=== KILL OLD BLUEBINDER ONLY ==="
  for P in $(pgrep -x bluebinder 2>/dev/null || true); do
    echo "KILL_OLD_BLUEBINDER_PID=$P"
    kill "$P" 2>/dev/null || true
  done
  sleep 2

  if pgrep -x bluebinder >/dev/null 2>&1; then
    echo "RESULT=ABORT_BLUEBINDER_STILL_RUNNING"
    exit 20
  fi

  echo
  echo "=== APPLY TTY PERMS ==="
  chmod 666 /dev/ttyHS0 2>/dev/null || true
  chmod 666 "/proc/$HAL_PID/root/dev/ttyHS0" 2>/dev/null || true
  ls -l /dev/ttyHS0 "/proc/$HAL_PID/root/dev/ttyHS0" 2>&1 || true

  echo
  echo "=== START BLUEBINDER BACKGROUND, MANUAL-HARNESS STYLE ==="
  /usr/sbin/bluebinder > "$D/bluebinder.stdout.log" 2> "$D/bluebinder.stderr.log" &
  BB_PID="$!"
  echo "$BB_PID" > /run/taba7-bluebinder-final.pid
  echo "BB_PID=$BB_PID"

  echo
  echo "=== WAIT SAFE: NO HCICONFIG / NO BTMGMT DURING INIT ==="
  INIT_OK="NO"
  for i in $(seq 1 35); do
    HCI_LIST="$(ls /sys/class/bluetooth 2>/dev/null | tr '\n' ' ' || true)"
    INIT_OK="NO"
    grep -q "Bluetooth binder initialized successfully" "$D/bluebinder.stderr.log" "$D/bluebinder.stdout.log" 2>/dev/null && INIT_OK="YES"
    echo "WAIT i=$i hci_list=$HCI_LIST init=$INIT_OK"

    [ "$INIT_OK" = "YES" ] && break

    if ! kill -0 "$BB_PID" 2>/dev/null; then
      echo "BLUEBINDER_EXITED_DURING_INIT"
      break
    fi

    sleep 1
  done

  echo
  echo "=== POST-INIT SYSFS STATE ONLY ==="
  ls -la /sys/class/bluetooth 2>&1 || true
  ls -la /sys/class/rfkill 2>&1 || true
  rfkill list 2>&1 || true

  echo
  echo "=== BLUEBINDER STDERR TAIL ==="
  tail -160 "$D/bluebinder.stderr.log" 2>/dev/null || true

  echo
  echo "=== BLUEBINDER STDOUT TAIL ==="
  tail -160 "$D/bluebinder.stdout.log" 2>/dev/null || true

  if [ "$INIT_OK" = "YES" ] && [ -d /sys/class/bluetooth/hci0 ]; then
    echo "RESULT=TABA7_CUSTOM_BLUEBINDER_STARTED_OK"
    exit 0
  else
    echo "RESULT=TABA7_CUSTOM_BLUEBINDER_CHECK_LOGS"
    exit 1
  fi
} > "$D/wrapper.log" 2>&1

exit $?
