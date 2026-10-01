# Manual installation for SM-T500 (developer preview)

This document records the manually tested installation route for Ubuntu Touch
24.04 / Halium 12 on the Samsung Galaxy Tab A7 Wi-Fi.

> [!CAUTION]
> This procedure erases userdata and flashes boot-critical partitions. A
> mistake can leave the tablet unable to boot. Back up everything first and
> keep matching Samsung firmware available for recovery.

> [!WARNING]
> These instructions and all Ubuntu Touch images are only for the Wi-Fi
> **SM-T500** (`gta4lwifi`). Do not flash them on SM-T505, SM-T505C, SM-T505N,
> SM-T507, `gta4l`, or any other model. The tested OrangeFox archive has
> `gta4l` in its filename because its upstream directory serves both device
> families; that does not make this port's images safe for LTE tablets.

This is not a UBports Installer workflow. It requires a release image set or
locally built images that are not stored in this Git repository.

> [!IMPORTANT]
> The older `Install_Directions.txt` bundled in the SourceForge archives is
> known not to describe a reliable complete installation. Do not use it as the
> authority for partition preparation or installation order. This document
> supersedes those instructions and records the maintainer-confirmed working
> route. SourceForge and GitHub Releases are referenced here only as
release-artifact hosts.

## Evidence and limitations

The maintainer performed the successful installation as follows:

1. Install the specified LineageOS 19.1 ZIP through OrangeFox.
2. Reformat userdata as ext4 from an ADB shell in OrangeFox.
3. Flash the Ubuntu Touch boot and DTBO images with Heimdall.
4. Copy `rootfs.img` and `system.img` to `/data` through ADB.
5. Boot Ubuntu Touch.
6. Apply the audio/Wi-Fi post-install layer bundled in the June 5 release.

The exact historical ADB formatting command was not retained. The command
below is a reconstruction based on the tested procedure, the port's ext4
recovery fstab, the confirmed userdata block-device identity, and the Halium
boot script's own `mke2fs -t ext4` implementation.

The exact OrangeFox build and LineageOS package listed below were confirmed by
the maintainer. OrangeFox is an unofficial third-party build. Neither package
is maintained by UBports or by this repository.

The maintainer's working Lomiri/display results remain the established port
baseline. A later [tester report in issue #4](https://github.com/jojobear691/ubuntu-touch-samsung-gta4lwifi/issues/4#issuecomment-5917095263)
identified an image-path mismatch when reproducing this procedure with the
June 5 pack. Copying the embedded Android image to userdata let that tester's
Android container start, but they still reported graphics/linker/composer
errors. The source correction below addresses image selection and mounting;
it does not establish that those separate tester graphics errors are fixed.

## Required files

### Android base

The tested Android base package was:

```text
lineage-19.1-20260529-UNOFFICIAL-gta4lwifi-nofirmwareassert.zip
Size: 903,365,460 bytes
SHA-256: f3f88ac09843afd7fc07e6e6ff5202af4b4ba016f1a52805230156c7745ed85a
```

Direct download:

<https://github.com/jojobear691/ubuntu-touch-samsung-gta4lwifi/releases/download/android-base-20260529/lineage-19.1-20260529-UNOFFICIAL-gta4lwifi-nofirmwareassert.zip>

Release notes and provenance:

<https://github.com/jojobear691/ubuntu-touch-samsung-gta4lwifi/releases/tag/android-base-20260529>

The published file is the exact package used in the maintainer-tested
installation. It was derived from the locally built
`lineage-19.1-20260529-UNOFFICIAL-gta4lwifi.zip` (SHA-256
`69a7ddd4c92acc135c5ea3b7b42d280c31b12b5996afd25393eccd9dbe0ec5bd`).
The only package change recorded during creation was removal of the
`samsung.verify_trustzone("XF.5.1-01015-1")` updater assertion.

This ZIP installs the matching Android 12 `system`, `vendor`, `product`, and
`odm` logical partitions. Its updater also flashes its own boot, DTBO, and
vbmeta images. Inspection with `avbtool` reported vbmeta flags `3`, meaning
hashtree and AVB verification are disabled.

The June 5 and June 20 SourceForge packs both omit this ZIP. Download it
separately from the GitHub release above and verify its checksum. The tested
procedure still depends on this exact Android base; do not substitute another
LineageOS build or Android base.

### Tested recovery

The recovery used for the successful installation was:

```text
OrangeFox-R11.3-Unofficial-gta4l.zip
Size: 74,375,663 bytes
SHA-256: b84fec44e54577d2ffe85fb2b2ef2c54fe7a83c0a07b269d03c235b79f119697
```

Original download directory:

<https://sourceforge.net/projects/yf-builds/files/Custom%20recovery/gta4l%2Bgta4lwifi/OrangeFox/>

Verify both the filename and checksum. This is an unofficial recovery; use it
at your own risk. These instructions assume it is already installed and can
mount `/data`, run an ADB shell, and install ZIP packages. Installing a custom
recovery is outside the currently verified scope of this guide.

### Ubuntu Touch image set

The fully evidenced release for this procedure is:

```text
SM-T500-gta4lwifi-UbuntuTouch-24.04-Halium12-FULL-INSTALL-PACK-WORKING-AUDIO-WIFI-20260605.tar.gz
SHA-256: 82f3cb5bcd7da1d73f8df96d43ac74e2d7dbb18e87bb8435319141946211d0fa
```

Download page:

<https://sourceforge.net/projects/ubuntu-touch-galaxy-tab-a7/files/SM-T500-gta4lwifi-UbuntuTouch-24.04-Halium12-FULL-INSTALL-PACK-WORKING-AUDIO-WIFI-20260605.tar.gz/download>

SourceForge also labels a June 20 `AS-IS-CURRENT` snapshot as newer. That
snapshot is not the baseline documented here. Do not mix its files with the
June 5 set.

Verify the outer archive before extracting it:

```bash
PACK='SM-T500-gta4lwifi-UbuntuTouch-24.04-Halium12-FULL-INSTALL-PACK-WORKING-AUDIO-WIFI-20260605.tar.gz'
printf '%s  %s\n' \
  '82f3cb5bcd7da1d73f8df96d43ac74e2d7dbb18e87bb8435319141946211d0fa' \
  "$PACK" | sha256sum --check -
```

Stop unless the result is `OK`. Extract the archive and enter its directory:

```bash
tar -xzf "$PACK"
cd SM-T500-gta4lwifi-UbuntuTouch-24.04-Halium12-FULL-INSTALL-PACK-WORKING-AUDIO-WIFI-20260605
```

The package provides a matched image set:

```text
images/boot.img
images/dtbo.img
images/rootfs.img
images/system.img
SHA256SUMS.txt
```

It does not contain the LineageOS ZIP. Obtain that exact file separately from
the GitHub release linked above. The package does contain the historical
audio/Wi-Fi post-install layer used by this procedure. The package's old
`Install_Directions.txt` is not authoritative; use this guide instead.

Do not combine images from different builds. Do not use
`prebuilt/gta4lwifi/dtbo.img` directly as a substitute for a complete release
image set. Verify the release checksums from the directory containing the
checksum file:

```bash
sha256sum --check SHA256SUMS.txt
```

Stop if any checksum fails.

Verify the separately downloaded LineageOS ZIP:

```bash
LINEAGE_ZIP='lineage-19.1-20260529-UNOFFICIAL-gta4lwifi-nofirmwareassert.zip'
printf '%s  %s\n' \
  'f3f88ac09843afd7fc07e6e6ff5202af4b4ba016f1a52805230156c7745ed85a' \
  "$LINEAGE_ZIP" |
  sha256sum --check -
```

Stop unless that result is also `OK`.

## Host requirements

Use a Linux host with:

- ADB
- Heimdall
- `sha256sum`
- a reliable USB data cable
- enough free disk space for the images

The tablet must have:

- an unlocked bootloader;
- a compatible Samsung Android 12 firmware baseline;
- the tested Android 12 / LineageOS 19.1 vendor and ODM base;
- working Samsung Download Mode;
- working OrangeFox recovery access.

Do not use fastboot for the Samsung partition-flashing steps in this guide.

## 1. Confirm the device

In Android or recovery, inspect the model and codename before flashing. The
only supported identity is:

```text
Model: SM-T500
Codename: gta4lwifi
```

Stop immediately if the model is an LTE variant or the identity is uncertain.

## 2. Install the tested LineageOS base

Boot OrangeFox and install this ZIP using OrangeFox's on-device Install action:

```text
lineage-19.1-20260529-UNOFFICIAL-gta4lwifi-nofirmwareassert.zip
```

Wait for installation to finish successfully. The package's updater writes
the Android system, vendor, product, and ODM partitions and also writes boot,
DTBO, and disabled vbmeta. Do not boot LineageOS and configure personal data;
userdata is erased in the next step.

## 3. Reformat userdata as ext4

> [!CAUTION]
> This step permanently erases every file in userdata, including internal
> storage. The block-device check is mandatory. Do not continue if it resolves
> to anything other than the SM-T500 userdata partition shown below.

Keep the tablet in OrangeFox and confirm that ADB sees it:

```bash
adb devices
```

Resolve the stable userdata name:

```bash
adb shell 'readlink -f /dev/block/by-name/userdata'
```

The tested SM-T500 layout resolves to:

```text
/dev/block/mmcblk0p80
```

Stop if the result is empty or different. Open an interactive recovery shell:

```bash
adb shell
```

Inside that shell, check whether `/data` is mounted:

```sh
mount | grep ' /data '
```

If the command displays a `/data` mount, unmount it:

```sh
umount /data
```

Confirm that the mount is gone. This command should print nothing:

```sh
mount | grep ' /data '
```

Create the ext4 filesystem using the stable partition name:

```sh
mke2fs -t ext4 /dev/block/by-name/userdata
```

If `mke2fs` identifies the old filesystem and asks for confirmation, carefully
confirm only after rechecking the partition name. Do not add force options to
work around an unexpected error.

Verify the result:

```sh
blkid /dev/block/by-name/userdata
```

The output must report `TYPE="ext4"`. Mount it and confirm that it is writable:

```sh
mkdir -p /data
mount -t ext4 /dev/block/by-name/userdata /data
df -h /data
touch /data/.ut-install-write-test
rm /data/.ut-install-write-test
exit
```

Do not continue unless every command succeeds.

## 4. Flash Ubuntu Touch boot and DTBO

Power off the tablet and enter Samsung Download Mode manually. With the tablet
powered off, hold Volume Up and Volume Down while connecting the USB cable,
then follow the device prompt to enter Download Mode.

From the extracted Ubuntu Touch release directory, verify that Heimdall detects
the tablet:

```bash
sudo heimdall detect
```

Flash the matching boot and DTBO images without automatic reboot:

```bash
sudo heimdall flash \
  --BOOT images/boot.img \
  --DTBO images/dtbo.img \
  --no-reboot
```

Do not flash a separate vbmeta image when using the exact tested LineageOS ZIP:
that package already installed its disabled vbmeta. If a different base package
was used, stop; that combination is not covered by this guide.

After Heimdall completes successfully, reboot manually into OrangeFox rather
than allowing the tablet to attempt its first Ubuntu Touch boot yet.

## 5. Copy rootfs.img and system.img

In OrangeFox, mount `/data`. Confirm it is mounted as ext4:

```bash
adb shell 'mount | grep " /data " && df -h /data'
```

Copy the two large images:

```bash
adb push images/rootfs.img /data/rootfs.img
adb push images/system.img /data/system.img
```

Confirm that both destination files exist and flush pending writes:

```bash
adb shell 'ls -l /data/rootfs.img /data/system.img && sync'
```

Compare the reported byte sizes with the host files:

```bash
stat -c '%n %s' images/rootfs.img images/system.img
```

Do not continue if either transfer failed or a size differs.

### Android image selection in corrected boot builds

A boot image rebuilt with the corrected `ramdisk-overlay/scripts/halium`
mounts the exact file found by image detection. `rootfs.img` on userdata does
not force the Android image to be on userdata too. At boot, userdata is mounted
at `/tmpmnt` and the Ubuntu image at `/halium-system`.

The existing detection priority is preserved, highest first:

1. `/halium-system/var/lib/lxc/android/android-rootfs.img`
2. `/halium-system/var/lib/lxc/android/system.img`
3. `/tmpmnt/android-rootfs.img`
4. `/tmpmnt/system.img`

`android-rootfs.img` is mounted as the Android root filesystem; `system.img`
is mounted as Android's system filesystem and its Android ramdisk is extracted.
With the embedded image present, the corrected boot script uses it directly.
No extra `/data/android-rootfs.img` copy or image rename is needed. Keep the
release's `rootfs.img` and `system.img` together as above.

### Older published boot images

Editing this repository does not change the `boot.img` already in the June 5
or June 20 archives. Those images must not be described as containing this
source fix without inspecting or rebuilding their ramdisks.

For the June 5 boot image, the tester's recovery workaround was to copy the
embedded Android image unchanged onto userdata. After the transfers above,
from an interactive OrangeFox shell (`adb shell`):

```sh
mkdir -p /tmp/ut-rootfs
mount -o loop,ro /data/rootfs.img /tmp/ut-rootfs
sha256sum /tmp/ut-rootfs/var/lib/lxc/android/android-rootfs.img
```

For the image reported in issue #4, the hash was
`7b5916f4fc28b0e3f249a564269791d42afd2b9f034378fb6528ed9f14ccb80d`.
Stop if the image is absent or differs from this June 5 identity. Copy and
verify it, keeping the Ubuntu image mounted read-only:

```sh
cp /tmp/ut-rootfs/var/lib/lxc/android/android-rootfs.img /data/android-rootfs.img
sha256sum /tmp/ut-rootfs/var/lib/lxc/android/android-rootfs.img /data/android-rootfs.img
sync
umount /tmp/ut-rootfs
exit
```

Both hashes must match. This records the tester's container-start workaround,
not a successful complete installation on that tablet. Prefer the corrected
script in a future matched release rather than making this duplicate image a
permanent installation requirement.

## 6. First boot

Use OrangeFox's interface to reboot manually into System. First boot can take
longer than an ordinary boot. The expected result is the Ubuntu Touch / Lomiri
interface.

Do not repeatedly interrupt a first boot merely because the display remains on
the boot animation for several minutes. If it never reaches Lomiri, return to
recovery and recheck:

- userdata is ext4;
- `/data/rootfs.img` exists and has the correct size;
- `/data/system.img` exists and has the correct size;
- boot and DTBO came from the same Ubuntu Touch build;
- the tested Android 12 vendor and ODM base was installed.

The Halium ramdisk locates `rootfs.img` on userdata and mounts the selected
Android image for LXC from its detected path. For the older boot-image
workaround, also verify `/data/android-rootfs.img` against its embedded source.

## 7. Apply the bundled audio/Wi-Fi layer

The June 5 full release includes the historical post-install layer that made
speaker audio and Wi-Fi work in the confirmed installation. It is distributed
in the SourceForge release, not tracked in this Git repository.

The inner helper archive used during development was:

```text
taba7-ut-install-layer-20260605-audio-wifi.tar.gz
SHA-256: 2f52461f193ba2f0b1f5a05093791bb5d3dc802a736064bed5f13631e373c31b
```

The full pack also provides the extracted helper directory at:

```text
install-layer/taba7-ut-install-layer/
```

Before executing anything with `sudo`, inspect the directory and especially
`files/taba7-wlan-on.sh`. Do not post its contents publicly if it contains a
network name, password, address, or other private configuration:

```bash
find install-layer/taba7-ut-install-layer -maxdepth 2 -type f -print
sed -n '1,260p' install-layer/taba7-ut-install-layer/install.sh
sed -n '1,360p' install-layer/taba7-ut-install-layer/files/taba7-wlan-on.sh
```

Wait until Ubuntu Touch has booted and SSH access for the `phablet` user works.
During development the USB-network address was `10.42.0.1`; it can differ, so
replace the example only after confirming the tablet's actual address:

```bash
TABLET_IP='10.42.0.1'
scp -r install-layer/taba7-ut-install-layer \
  "phablet@$TABLET_IP:/tmp/"
ssh "phablet@$TABLET_IP"
```

On the tablet, install and verify the layer:

```sh
cd /tmp/taba7-ut-install-layer
sudo sh ./install.sh
sudo sh ./verify.sh
```

Exit the SSH session, reboot through the tablet interface, wait for Lomiri to
return, and reconnect over SSH. The two newly enabled services are expected to
run during that boot.

The installer writes the working files under `/userdata/ut-scripts` and
`/userdata/ut-audio`, installs two systemd units under `/etc/systemd/system`,
and creates logs and timestamped backups under `/userdata/ut-logs` and
`/userdata/ut-backups`.

Expected enabled units:

```text
taba7-audio-known-good.service
taba7-wlan-on.service
```

Expected disabled older experimental audio units:

```text
taba7-audio-hidl.service
taba7-android-audio-hal.service
taba7-audio-pulse-late.service
```

Confirm the services without exposing private network configuration:

```sh
sudo systemctl is-enabled \
  taba7-audio-known-good.service \
  taba7-wlan-on.service
sudo systemctl status --no-pager \
  taba7-audio-known-good.service \
  taba7-wlan-on.service
pactl info
pactl list short sinks
pactl list short cards
nmcli device status
ip address show wlan0
```

The known-good audio state has default sink `sink.primary-out` and card
`droid_card.primary`. The expected Wi-Fi interface is `wlan0`. Audio may need a
few seconds after the interface appears; play a sound and adjust the hardware
volume before diagnosing failure.

### Roll back the post-install layer

If the source directory remains in `/tmp`, run:

```sh
cd /tmp/taba7-ut-install-layer
sudo sh ./rollback.sh
```

Because `/tmp` may be cleared by rebooting, copy the helper directory to the
tablet again if `rollback.sh` is no longer present. The installer reports the
timestamped backup path in `/userdata/ut-backups`; preserve that path and the
installation log when troubleshooting.

## What this repository does not distribute

This source repository intentionally excludes:

- Samsung or Qualcomm proprietary firmware;
- LineageOS installation ZIPs in the Git source tree (the exact tested ZIP is
  published separately as a GitHub release asset);
- OrangeFox binaries;
- generated Ubuntu Touch installation images;
- the release-bundled audio/Wi-Fi helper layer;
- private device logs, credentials, Bluetooth keys, and Wi-Fi credentials.

Release artifacts must be distributed separately with their own provenance,
licenses, and checksums.

## Recovery and rollback

Keep the tested LineageOS ZIP, OrangeFox recovery, Samsung firmware, and the
release checksums before starting. Reinstalling LineageOS or Samsung firmware
overwrites boot-critical partitions and is outside this guide's verified Ubuntu
Touch installation route.

Do not experiment with LTE images, repartitioning, raw block-device writes, or
unverified vbmeta files as recovery steps.

## Reporting installation results

When reporting a result, include only non-private information:

- exact model and codename;
- recovery filename and SHA-256;
- LineageOS base filename and SHA-256;
- Ubuntu Touch release/build identifier;
- whether Heimdall completed successfully;
- whether userdata was verified as ext4;
- whether Lomiri reached the first-run interface;
- whether the two post-install services were enabled and verified.

Remove serial numbers, network names, addresses, credentials, keys, and private
logs before posting publicly.
