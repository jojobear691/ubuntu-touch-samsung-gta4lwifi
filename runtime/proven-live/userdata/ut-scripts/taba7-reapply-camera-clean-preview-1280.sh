#!/bin/sh
set -eu

SRC_DIR="/home/phablet/camera-fixed-clean-preview-1280"
DST_DIR="/usr/share/click/preinstalled/camera.ubports/4.1.1/qml/Viewfinder"

VF_SRC="$SRC_DIR/ViewFinderOverlay.qml"
BC_SRC="$SRC_DIR/BarcodeReaderOverlay.qml"
VF_DST="$DST_DIR/ViewFinderOverlay.qml"
BC_DST="$DST_DIR/BarcodeReaderOverlay.qml"

echo TABA7_REAPPLY_CAMERA_CLEAN_PREVIEW_1280

for f in "$VF_SRC" "$BC_SRC" "$VF_DST" "$BC_DST"; do
  if [ ! -f "$f" ]; then
    echo "MISSING=$f"
    exit 1
  fi
done

bind_one() {
  src="$1"
  dst="$2"

  current="$(findmnt -rn -T "$dst" -o SOURCE 2>/dev/null || true)"

  if [ "$current" = "$src" ]; then
    echo "ALREADY_BOUND $src -> $dst"
    return 0
  fi

  if findmnt -rn -T "$dst" >/dev/null 2>&1; then
    echo "UNMOUNT_OLD_BIND=$dst"
    umount "$dst" || true
  fi

  echo "BIND $src -> $dst"
  mount --bind "$src" "$dst"
}

bind_one "$VF_SRC" "$VF_DST"
bind_one "$BC_SRC" "$BC_DST"

echo
echo ACTIVE_QML_BINDS
findmnt -rn | grep -E "camera-fixed-clean-preview-1280|ViewFinderOverlay.qml|BarcodeReaderOverlay.qml" || true

echo RESULT=MANUAL_QML_REAPPLY_DONE
