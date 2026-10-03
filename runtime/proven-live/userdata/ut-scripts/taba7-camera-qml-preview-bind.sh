#!/bin/sh
set -e

SRC_DIR="/home/phablet/camera-fixed-clean-preview-1280"
DST_DIR="/usr/share/click/preinstalled/camera.ubports/4.1.1/qml/Viewfinder"

for f in ViewFinderOverlay.qml BarcodeReaderOverlay.qml; do
  SRC="$SRC_DIR/$f"
  DST="$DST_DIR/$f"

  [ -f "$SRC" ] || {
    echo "MISSING_SRC=$SRC"
    exit 1
  }

  [ -f "$DST" ] || {
    echo "MISSING_DST=$DST"
    exit 1
  }

  if findmnt -rn -T "$DST" >/dev/null 2>&1; then
    echo "UNMOUNT_EXISTING=$DST"
    umount "$DST" 2>/dev/null || true
  fi

  mount --bind "$SRC" "$DST"
  echo "BOUND=$SRC -> $DST"
done

grep -nE 'TABA7_FIXED_CLEAN_PREVIEW_FILE_ACTIVE|TABA7_SUPPRESSED_SERVICE_MISSING_ERROR_POPUP|false && errorCode == Camera.ServiceMissingError' \
  "$DST_DIR/ViewFinderOverlay.qml" "$DST_DIR/BarcodeReaderOverlay.qml"
