#!/bin/bash
set +e

LOG="/userdata/ut-tests/taba7-camera-island-stop-$(date +%Y%m%d-%H%M%S).log"
mkdir -p /userdata/ut-tests
exec > >(tee -a "$LOG") 2>&1

echo "===== TABA7 CAMERA ISLAND STOP PROCESSFIX ====="
date
echo "LOG=$LOG"

APATH='export PATH=/system/bin:/system/xbin:/vendor/bin:/odm/bin:/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/sbin:/bin; set +e;'

A() {
  lxc-attach -n android -- /bin/sh -c "$APATH $1"
}

echo
echo "===== STOP ZYGOTE ====="
A '/system/bin/setprop ctl.stop zygote 2>/dev/null || true; /system/bin/setprop ctl.stop zygote_secondary 2>/dev/null || true'
sleep 1

echo
echo "===== KILL TEMP CAMERA ISLAND PROCESSES ONLY ====="
A '
for round in 1 2 3; do
  echo "--- kill round $round ---"
  ps -A | grep -E "ut_camera_ndk_probe|cameraserver-los|ut_camera_binder_stubs|mediaswcodec|zygote64|zygote|app_process64.real" | grep -v grep | while read -r line; do
    clean="$(echo "$line" | sed "s/^ *//; s/  */ /g")"
    pid="$(echo "$clean" | cut -d" " -f2)"
    name="$(echo "$clean" | sed "s/.* //")"

    case "$name" in
      android.hardware.camera.provider@2.4-service_64|*camera.provider*)
        echo "SKIP_REAL_PROVIDER pid=$pid name=$name"
        ;;
      ut_camera_ndk_probe|cameraserver-los|ut_camera_binder_stubs|mediaswcodec|zygote64|zygote|app_process64.real)
        echo "KILL_TEMP pid=$pid name=$name"
        kill -9 "$pid" 2>/dev/null || true
        ;;
      *)
        echo "SKIP_UNKNOWN pid=$pid name=$name"
        ;;
    esac
  done

  /system/bin/setprop ctl.stop zygote 2>/dev/null || true
  /system/bin/setprop ctl.stop zygote_secondary 2>/dev/null || true
  sleep 1
done
'

echo
echo "===== UNMOUNT TEMP BINDS ====="
A '
for m in /linkerconfig /apex/com.android.art /system; do
  if mount | grep -q " on $m "; then
    echo "TRY_UMOUNT=$m"
    umount "$m" 2>/dev/null
    rc=$?
    echo "UMOUNT_PATH=$m RC=$rc"
    if mount | grep -q " on $m "; then
      echo "STILL_MOUNTED=$m"
      umount -l "$m" 2>/dev/null
      echo "LAZY_UMOUNT_PATH=$m RC=$?"
    fi
  else
    echo "NOT_MOUNTED=$m"
  fi
done
'

echo
echo "===== STOP AFTER STATE ====="
echo "lightdm=$(systemctl is-active lightdm 2>&1)"
A '
echo "sys.powerctl=$(/system/bin/getprop sys.powerctl 2>/dev/null)"
echo "zygote=$(/system/bin/getprop init.svc.zygote 2>/dev/null)"
echo "zygote_secondary=$(/system/bin/getprop init.svc.zygote_secondary 2>/dev/null)"
echo "media.camera=$(/system/bin/service check media.camera 2>&1)"
echo "processinfo=$(/system/bin/service check processinfo 2>&1)"
ps -A | grep -E "cameraserver-los|ut_camera_binder_stubs|mediaswcodec|zygote64|zygote|app_process64|camera.provider" | grep -v grep || true
mount 2>/dev/null | grep -E " on /system | on /linkerconfig | on /apex/com.android.art " || true
'

echo
echo "===== CAMERA ISLAND STOP DONE ====="
exit 0
