"""Run the actual image-selection/mount shell code against temporary files.

No mounts, image parsing, device access, root privileges, or ROM build required.
"""

import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


SCRIPT = Path(os.environ.get(
    "HALIUM_SCRIPT", str(Path(__file__).resolve().parents[1] /
                         "ramdisk-overlay/scripts/halium")))


class ImageLayoutTest(unittest.TestCase):
    def exercise(self, mask, layout, writable=False, mount_status=0):
        source = SCRIPT.read_text()
        # Source functions without calling mountroot or its device operations.
        mount_block = source.split(
            "\t# Mount the android system partition to a temporary location\n", 1
        )[1].split("\n\tidentify_boot_mode\n", 1)[0]
        with tempfile.TemporaryDirectory(prefix="halium-layout-") as tmp:
            base = Path(tmp)
            userdata = base / "userdata"
            rootfs = base / "ubuntu"
            embedded = rootfs / "var/lib/lxc/android"
            userdata.mkdir()
            embedded.mkdir(parents=True)
            if layout == "halium":
                (userdata / "rootfs.img").touch()
            elif layout == "legacy":
                (userdata / "ubuntu.img").touch()
            elif layout == "subdir":
                (userdata / "halium-rootfs").mkdir()
            candidates = [userdata / "system.img", userdata / "android-rootfs.img",
                          embedded / "system.img", embedded / "android-rootfs.img"]
            present = [p for i, p in enumerate(candidates) if mask & (1 << i)]
            for path in present:
                path.touch()
            if writable:
                (rootfs / ".writable_device_image").touch()
            # Rewrite only the two filesystem prefixes to an isolated fixture.
            def fixture(text):
                return text.replace("/tmpmnt", str(userdata)).replace(
                    "/halium-system", str(rootfs))
            shell = fixture(source) + '''
tell_kmsg() { printf 'LOG:%s\n' "$1"; }
mount() { printf 'MOUNT'; printf '|%s' "$@"; printf '\n'; return "$mount_status"; }
extract_android_ramdisk() { printf 'EXTRACT\n'; }
ANDROID_IMAGE_MODE=stale
ANDROID_IMAGE_PATH=/stale/image
identify_file_layout
identify_android_image
printf 'STATE:%s|%s|%s\n' "$file_layout" "$ANDROID_IMAGE_MODE" "$ANDROID_IMAGE_PATH"
''' + fixture(mount_block) + "\n: \n"
            result = subprocess.run(
                ["/bin/sh", "-c", "mount_status=" + shlex.quote(str(mount_status))
                 + "\n" + shell], check=True, capture_output=True, text=True)
            lines = result.stdout.splitlines()
            expected = present[-1] if present else None
            mode = ("rootfs" if expected.name == "android-rootfs.img" else "system"
                    ) if expected else "unknown"
            mounts = [line for line in lines if line.startswith("MOUNT")]
            if expected:
                self.assertEqual(mounts[0],
                                 f"MOUNT|-o|loop,{'rw' if writable else 'ro'}|"
                                 f"{expected}|/android-{mode}")
                if mode == "rootfs":
                    self.assertEqual(mounts[1:],
                                     ["MOUNT|-o|bind|/android-rootfs/system|/android-system"])
                    self.assertNotIn("EXTRACT", lines)
                else:
                    self.assertEqual(len(mounts), 1)
                    self.assertIn("EXTRACT", lines)
                if mount_status:
                    self.assertIn(f"LOG:WARNING: Failed to mount Android image {expected}.", lines)
            else:
                self.assertEqual(mounts, [])
                self.assertNotIn("EXTRACT", lines)
            self.assertIn(f"STATE:{layout}|{mode}|{expected or ''}", lines)

    def test_all_candidate_combinations_and_layouts(self):
        for layout in ("halium", "legacy", "subdir", "partition"):
            for mask in range(16):
                with self.subTest(layout=layout, candidates=mask):
                    self.exercise(mask, layout)

    def test_writable_device_image(self):
        self.exercise(9, "halium", writable=True)

    def test_mount_failure_names_selected_image(self):
        self.exercise(9, "halium", mount_status=1)


if __name__ == "__main__":
    unittest.main()
