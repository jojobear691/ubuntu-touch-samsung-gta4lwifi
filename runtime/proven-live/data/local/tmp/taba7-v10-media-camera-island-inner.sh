#!/system/bin/sh
set +e

SYSTEM_SRC="/data/local/tmp/ut-framework-island/init-zygote-full-framework-artlibs-20260607-130027/system-live"
LINKER_SRC="/data/local/tmp/ut-framework-island/init-zygote-full-framework-artlibs-20260607-130027/linkerconfig-live"
PATCHED_CAMERASERVICE_SHA="6592667490431d1d3fbfe670fa1538b6c690b83303d53cc45f108a5e00afc0cd"
REAL_TRUST_CAMERASERVICE="/data/local/tmp/libcameraservice-real-trust-agent-20260615-1733.so"
LINKER_SHA="0ff482bfc2381671a2d98b17c8dac0b58325c81f3cb2cf0d6690da68b2bfb410"
APEX_LIB_SHA="7d29854caf40c2d5a493f303b18e56d92def3ddb908e0213990b539c507ebeeb"
CALL="/system/bin/service call media.camera 17 i32 1 i32 1 i32 0"

log() {
  echo "[$(/system/bin/date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)] $*"
}

sha1_of() {
  /system/bin/sha256sum "$1" 2>/dev/null | /system/bin/awk '{print $1}'
}

log "===== ANDROID INNER V10 MEDIA/CAMERA ISLAND START ====="
log "sys.powerctl=$(/system/bin/getprop sys.powerctl 2>/dev/null)"
log "provider=$(/system/bin/getprop init.svc.vendor.camera-provider-2-4 2>/dev/null)"

if [ -n "$(/system/bin/getprop sys.powerctl 2>/dev/null)" ]; then
  log "ABORT: sys.powerctl is set"
  exit 20
fi

if [ ! -d "$SYSTEM_SRC" ]; then
  log "ABORT: missing SYSTEM_SRC=$SYSTEM_SRC"
  exit 21
fi

if [ ! -f "$LINKER_SRC/ld.config.txt" ] || [ ! -f "$LINKER_SRC/apex.libraries.config.txt" ]; then
  log "ABORT: missing linkerconfig files under $LINKER_SRC"
  exit 22
fi

log "----- pre-mount hashes -----"
/system/bin/sha256sum /system/lib64/libcameraservice.so 2>/dev/null || true
/system/bin/sha256sum /linkerconfig/ld.config.txt /linkerconfig/apex.libraries.config.txt 2>/dev/null || true

CUR_LINKER="$(sha1_of /linkerconfig/ld.config.txt)"
if [ "$CUR_LINKER" != "$LINKER_SHA" ]; then
  log "mounting linkerconfig-live over /linkerconfig"
  /system/bin/mount --bind "$LINKER_SRC" /linkerconfig 2>&1
  log "LINKER_MOUNT_RC=$?"
else
  log "linkerconfig-live already visible"
fi

CUR_CAM="$(sha1_of /system/lib64/libcameraservice.so)"
if [ "$CUR_CAM" != "$PATCHED_CAMERASERVICE_SHA" ]; then
  log "mounting system-live over /system"
  /system/bin/mount --bind "$SYSTEM_SRC" /system 2>&1
  log "SYSTEM_MOUNT_RC=$?"
else
  log "system-live already visible"
fi

log "----- bind real trust-agent libcameraservice if needed -----"
if [ ! -f "$REAL_TRUST_CAMERASERVICE" ]; then
  log "ABORT: missing REAL_TRUST_CAMERASERVICE=$REAL_TRUST_CAMERASERVICE"
  exit 25
fi
if [ "$(sha1_of /system/lib64/libcameraservice.so)" != "$PATCHED_CAMERASERVICE_SHA" ]; then
  log "binding real trust-agent libcameraservice over /system/lib64/libcameraservice.so"
  /system/bin/umount /system/lib64/libcameraservice.so 2>/dev/null || true
  /system/bin/mount --bind "$REAL_TRUST_CAMERASERVICE" /system/lib64/libcameraservice.so 2>&1
  log "REAL_TRUST_CAMERASERVICE_BIND_RC=$?"
else
  log "real trust-agent libcameraservice already visible"
fi

log "----- post-mount hashes -----"
/system/bin/sha256sum /system/lib64/libcameraservice.so /linkerconfig/ld.config.txt /linkerconfig/apex.libraries.config.txt 2>/dev/null || true

if [ "$(sha1_of /system/lib64/libcameraservice.so)" != "$PATCHED_CAMERASERVICE_SHA" ]; then
  log "ABORT: patched libcameraservice not visible"
  exit 23
fi

if [ "$(sha1_of /linkerconfig/ld.config.txt)" != "$LINKER_SHA" ]; then
  log "ABORT: linkerconfig ld.config not visible"
  exit 24
fi

log "----- start media.swcodec if needed -----"
if /system/bin/pidof media.swcodec >/dev/null 2>&1; then
  log "media.swcodec already running pid=$(/system/bin/pidof media.swcodec 2>/dev/null)"
else
  ( /apex/com.android.media.swcodec/bin/mediaswcodec > /data/local/tmp/taba7-v10-media.swcodec.log 2>&1 & )
  /system/bin/sleep 1
  log "media.swcodec pid=$(/system/bin/pidof media.swcodec 2>/dev/null)"
fi

log "----- start binder stubs v10 if needed -----"
if /system/bin/pidof ut_camera_binder_stubs_grant_v10 >/dev/null 2>&1; then
  log "ut_camera_binder_stubs_grant_v10 already running pid=$(/system/bin/pidof ut_camera_binder_stubs_grant_v10 2>/dev/null)"
else
  ( /data/local/tmp/ut_camera_binder_stubs_grant_v10 > /data/local/tmp/taba7-v10-binder-stubs.log 2>&1 & )
  /system/bin/sleep 1
  log "ut_camera_binder_stubs_grant_v10 pid=$(/system/bin/pidof ut_camera_binder_stubs_grant_v10 2>/dev/null)"
fi

for i in 1 2 3 4 5; do
  if /system/bin/service check processinfo 2>&1 | /system/bin/grep -q "Service processinfo: found"; then
    log "processinfo found at wait=$i"
    break
  fi
  /system/bin/sleep 1
done

log "----- start cameraserver-los if needed -----"
if /system/bin/pidof cameraserver-los >/dev/null 2>&1; then
  log "cameraserver-los already running pid=$(/system/bin/pidof cameraserver-los 2>/dev/null)"
else
  ( /data/local/tmp/cameraserver-los > /data/local/tmp/taba7-v10-cameraserver-los.log 2>&1 & )
  /system/bin/sleep 1
  log "cameraserver-los pid=$(/system/bin/pidof cameraserver-los 2>/dev/null)"
fi

log "----- wait for media.camera -----"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  MC="$(/system/bin/service check media.camera 2>&1)"
  log "wait_media_camera_$i=$MC"
  echo "$MC" | /system/bin/grep -q "Service media.camera: found" && break
  /system/bin/sleep 1
done

log "----- apply exact user0 notify -----"
$CALL 2>&1
log "USER0_NOTIFY_RC=$?"
/system/bin/sleep 1

log "----- final state -----"
echo "sys.powerctl=$(/system/bin/getprop sys.powerctl 2>/dev/null)"
echo "zygote=$(/system/bin/getprop init.svc.zygote 2>/dev/null)"
echo "provider=$(/system/bin/getprop init.svc.vendor.camera-provider-2-4 2>/dev/null)"
echo "media.camera=$(/system/bin/service check media.camera 2>&1)"
echo "processinfo=$(/system/bin/service check processinfo 2>&1)"
echo "media.swcodec_process=$(/system/bin/pidof media.swcodec 2>/dev/null)"
echo "binder_stubs_process=$(/system/bin/pidof ut_camera_binder_stubs_grant_v10 2>/dev/null)"
echo "cameraserver_los_process=$(/system/bin/pidof cameraserver-los 2>/dev/null)"
/system/bin/ps -A | /system/bin/grep -Ei "camera.provider|cameraserver-los|media.swcodec|ut_camera_binder_stubs_grant_v10|zygote" | /system/bin/grep -v grep || true

echo
/system/bin/dumpsys media.camera 2>/dev/null | /system/bin/grep -Ei "Number of camera devices|Device [0-9] maps|Allowed user IDs|USER_SWITCH|Active Camera Clients|Camera error traces" -A10 -B4 | /system/bin/head -160 || true

log "===== ANDROID INNER V10 MEDIA/CAMERA ISLAND END ====="
