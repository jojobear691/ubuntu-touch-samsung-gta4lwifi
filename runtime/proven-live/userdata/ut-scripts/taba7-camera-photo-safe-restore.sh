#!/bin/sh
set +e

echo "TABA7_CAMERA_PHOTO_SAFE_RESTORE"

lxc-attach -n android -- sh -c '
  set +e

  echo "1_STOP_CAMERA_STACK"
  OLDCS="$(pidof cameraserver-los 2>/dev/null)"
  OLDPROV="$(pidof android.hardware.camera.provider@2.4-service_64 2>/dev/null)"
  echo OLD_CAMERASERVER_LOS_PID="$OLDCS"
  echo OLD_CAMERA_PROVIDER_PID="$OLDPROV"
  [ -n "$OLDCS" ] && kill "$OLDCS" 2>/dev/null
  [ -n "$OLDPROV" ] && kill "$OLDPROV" 2>/dev/null
  sleep 4

  echo "2_BIND_STOCK_CAMERA_QCOM"
  if [ -f /data/local/tmp/camera.qcom.stock.so ]; then
    mount --bind /data/local/tmp/camera.qcom.stock.so /vendor/lib64/hw/camera.qcom.so
    echo STOCK_CAMERA_QCOM_BIND_RC=$?
  else
    echo "NO_STOCK_CAMERA_QCOM_COPY"
  fi
  sha256sum /vendor/lib64/hw/camera.qcom.so 2>/dev/null || true

  echo "3_BIND_PHOTO_LIBCAMERASERVICE"
  PHOTO_LIB="/data/local/tmp/libcameraservice-real-trust-agent-photo-fixed-clean-20260620.so"
  if [ -f "$PHOTO_LIB" ]; then
    mount --bind "$PHOTO_LIB" /system/lib64/libcameraservice.so
    echo PHOTO_LIBCAMERASERVICE_BIND_RC=$?
  else
    echo "MISSING_PHOTO_LIB=$PHOTO_LIB"
  fi
  sha256sum /system/lib64/libcameraservice.so 2>/dev/null || true

  echo "4_RECREATE_FLASH_SUBDEVS"
  rm -f /dev/v4l-subdev14 /dev/v4l-subdev15 /dev/v4l-subdev16
  mknod /dev/v4l-subdev14 c 81 142
  mknod /dev/v4l-subdev15 c 81 143
  mknod /dev/v4l-subdev16 c 81 144
  chown system:camera /dev/v4l-subdev14 /dev/v4l-subdev15 /dev/v4l-subdev16
  chmod 660 /dev/v4l-subdev14 /dev/v4l-subdev15 /dev/v4l-subdev16
  restorecon /dev/v4l-subdev14 /dev/v4l-subdev15 /dev/v4l-subdev16 2>/dev/null || true

  echo "5_RESTART_PROVIDER_AND_CAMERASERVER"
  /vendor/bin/hw/android.hardware.camera.provider@2.4-service_64 >/data/local/tmp/provider-photo-safe-restore.log 2>&1 &
  sleep 5

  chmod 755 /data/local/tmp/cameraserver-los
  /data/local/tmp/cameraserver-los >/data/local/tmp/cameraserver-los-photo-safe-restore.log 2>&1 &
  sleep 8

  echo "6_CAMERA_HEALTH"
  service check media.camera || true
  dumpsys media.camera 2>/dev/null | grep -E "Number of camera devices|Allowed user IDs|Device [01] is|Has a flash unit|Facing" | head -180 || true

  echo "7_PROCESS_HASHES"
  PROV="$(pidof android.hardware.camera.provider@2.4-service_64 2>/dev/null)"
  CS="$(pidof cameraserver-los 2>/dev/null)"
  echo CAMERA_PROVIDER_PID="$PROV"
  echo CAMERASERVER_LOS_PID="$CS"
  [ -n "$PROV" ] && sha256sum /proc/$PROV/root/vendor/lib64/hw/camera.qcom.so 2>/dev/null || true
  [ -n "$CS" ] && sha256sum /proc/$CS/root/system/lib64/libcameraservice.so 2>/dev/null || true
'

echo "8_REGRANT_USER0"
/userdata/ut-scripts/taba7-camera-black-screen-rescue.sh 2>&1 || true

echo "RESULT=PHOTO_SAFE_RESTORE_DONE"
