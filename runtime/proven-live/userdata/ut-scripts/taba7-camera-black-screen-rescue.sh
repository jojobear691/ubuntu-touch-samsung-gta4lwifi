#!/bin/sh
set +e

PASS="jojobear"

echo TABA7_CAMERA_BLACK_SCREEN_RESCUE

echo 1_CLOSE_CAMERA_APP_ONLY
pkill -f 'lomiri-camera-app|camera-app|camera.ubports|qmlscene.*camera|camera\.ubports' 2>/dev/null || true
sleep 2

echo 2_REGRANT_USER0_WITH_TIMEOUT
printf "$PASS\n" | sudo -S timeout 8 lxc-attach -n android -- /system/bin/sh -c \
'service call media.camera 17 i32 1 i32 1 i32 0' 2>&1
RC=$?
echo "USER0_NOTIFY_RC=$RC"

if [ "$RC" = "124" ]; then
  echo 3_RESET_ONLY_CAMERASERVER_LOS

  printf "$PASS\n" | sudo -S lxc-attach -n android -- /system/bin/sh -c '
  set +e
  for p in $(pidof cameraserver-los 2>/dev/null); do
    echo "TERM_CAMERASERVER_LOS_PID=$p"
    kill -TERM "$p" 2>/dev/null || true
  done
  sleep 2
  for p in $(pidof cameraserver-los 2>/dev/null); do
    echo "KILL_CAMERASERVER_LOS_PID=$p"
    kill -KILL "$p" 2>/dev/null || true
  done
  nohup /data/local/tmp/cameraserver-los >/data/local/tmp/cameraserver-los-reset.log 2>&1 &
  sleep 2
  echo "CAMERASERVER_LOS_PID=$(pidof cameraserver-los 2>/dev/null)"
  ' 2>&1 || true

  echo 4_REGRANT_AFTER_RESET
  printf "$PASS\n" | sudo -S timeout 8 lxc-attach -n android -- /system/bin/sh -c \
  'service call media.camera 17 i32 1 i32 1 i32 0' 2>&1
  echo "USER0_NOTIFY_AFTER_RESET_RC=$?"
fi

echo 5_VERIFY
printf "$PASS\n" | sudo -S timeout 8 lxc-attach -n android -- /system/bin/sh -c '
service check media.camera
dumpsys media.camera | grep -E "Number of camera devices|Active Camera Clients|Allowed user IDs|Device [01] is|USER_SWITCH|ADD device|CONNECT|DISCONNECT|ERROR"
' 2>&1 || true

echo RESULT=CAMERA_BLACK_SCREEN_RESCUE_DONE
