#!/usr/bin/env bash
set +e

HAL_PID="$(pgrep -f '/vendor/bin/hw/android.hardware.bluetooth@1.0-service-qti' | head -1 || true)"

chmod 666 /dev/ttyHS0 2>/dev/null || true

if [ -n "$HAL_PID" ]; then
  chmod 666 "/proc/$HAL_PID/root/dev/ttyHS0" 2>/dev/null || true
fi

exit 0
