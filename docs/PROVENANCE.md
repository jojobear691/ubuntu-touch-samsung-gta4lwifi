# Source and artifact provenance

This document records the known origins and identities of imported
source files, compiled build inputs, and the device-specific camera
source changes in this repository.

It does not claim that every imported artifact was produced
reproducibly. Items whose exact producing source revision is unknown are
identified as such.

## Camera source publication

The known-working D1AA `libcameraservice` changes are published as
source only:

- `../patches/frameworks-av/gta4lwifi-libcameraservice-d1aa-known-working.patch`
- `../patches/frameworks-av/README.md`
- `../patches/frameworks-av/SECURITY.md`
- `../provenance/frameworks-av-d1aa-source-manifest.txt`
- `../checksums/SHA256SUMS`

The patch applies to LineageOS `android_frameworks_av`, branch
`lineage-19.1`, at base commit:

`8ad4e1d710fab315ff7ce461eed1efa60f282828`

The compiled `libcameraservice.so` is intentionally not included.

The source manifest records the expected known-working binary identity
for verification purposes:

- stripped SHA-256:
  `d1aa44ea12356830e61fe83fa9fd177244c91721d3730cd8aacc40408ee4c3bf`
- ELF Build ID:
  `d9ec4ea768df76fdcfa2beb89abee1ba`

Droidmedia is part of the known-working Ubuntu Touch camera path. The
published changes do not remove or replace it.

## Existing binary and image artifacts

### `prebuilt/gta4lwifi/dtb.img`

- Size: 3,950,482 bytes
- SHA-256:
  `32414e6f43b5a0bd42b1fb3cd20436f1e16095d4390bdaed151f3fe995b4112b`
- Type: compiled flattened device-tree data
- Exact producing build: not yet established

The public kernel source used by this port is:

<https://github.com/jojobear691/kernel-samsung-sm6115-halium12>

Downstream distributors should not describe this DTB as reproducibly
built until its exact producing source revision and build command are
recorded.

### `prebuilt/gta4lwifi/dtbo.img`

- Size: 25,165,824 bytes
- SHA-256:
  `a9cb39ba1cf0431ae73e4a83111698291f6b63c4706c7b530c7030ef7a60e691`
- Original DTBO payload size: 4,474,460 bytes
- Original payload SHA-256:
  `93b35099dd84d54d49de7db195dcd286836ba2bd3f98ecf7fe4ba4ac2625f1b5`

The original payload exactly matched the locally generated LineageOS
DTBO output inspected during publication review.

The remaining bytes are an Android Verified Boot hash footer and
partition padding. `avbtool info_image` reported:

- footer version 1.0;
- partition name `dtbo`;
- AVB algorithm `NONE`;
- hash algorithm SHA-256;
- release string `avbtool 1.2.0`;
- original image size 4,474,460 bytes.

`Algorithm: NONE` means that the included hash metadata is not
cryptographically signed. The embedded Samsung build fingerprint is
build identification, not a credential or private key.

### `ramdisk-overlay/ramdisk-recovery.img`

- Size: 10,601,150 bytes
- SHA-256:
  `a498d209d6c1ef71dbb3b47959f2e5fda21b316233762ca7ccb25ff0278cd478`
- Type: gzip-compressed Android recovery filesystem
- Archive entries observed during review: 372

This file is an exact copy from the UBports Google Pixel 3a/Sargo port
template at commit:

`7627dacca8171dc115de2135b1f94b1f1d72a1b5`

Template repository:

<https://gitlab.com/ubports/porting/community-ports/android12/google-pixel-3a/google-sargo>

The recovery filesystem contains components from multiple upstream
projects. Those components retain their respective licenses; this
repository's GPL-3.0 license does not replace them.

### `ramdisk-overlay/sbin/make-dynpart-mappings`

- Size: 71,912 bytes
- SHA-256:
  `c8ad213bc53c63fb99b2af96ddc8b6f663e1b3ac6e8a7aff0ed8fbaf0c403585`
- ELF Build ID:
  `c0f4a6af5f429b984f3e2159652a163ef2129237`
- Architecture: AArch64
- Compiler marker:
  `GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`

This binary is an exact copy from the same Sargo template and is related
to:

<https://gitlab.com/flamingradian/make-dynpart-mappings>

The exact source revision that produced this binary has not yet been
established. Downstream distributors should resolve that source
correspondence before claiming a reproducible build or complete
corresponding source.

## Imported boot and configuration files

### `ramdisk-overlay/scripts/halium`

- SHA-256:
  `e0eaa72aa1a63988803b7f1901df0d792d22636a9ae122581087436696543c9d`
- Git blob:
  `c957751e0825d2512036ebe84a271ee4e5982f5b`

This script is derived from Halium initramfs work but is not identical
to either the current upstream script or the Sargo-template copy
reviewed during publication.

Upstream project:

<https://github.com/Halium/initramfs-tools-halium>

It must therefore be described as an adapted Halium script. Its exact
historical base revision has not been established.

### `overlay/system/etc/ofono/ril_subscription.conf`

- SHA-256:
  `6fc94137c6047851007e0de5a26fec43c1cc8b45e5df9b3857be902472553289`

This is an exact Sargo-template copy based on the mer-hybris oFono RIL
configuration format:

<https://github.com/mer-hybris/ofono-ril-plugin/blob/master/ril_subscription.conf>

The SM-T500 is Wi-Fi-only. This cellular configuration is retained for
build compatibility pending a controlled test proving that it can be
removed.

### `overlay/system/lib/udev/rules.d/70-android.rules`

- SHA-256:
  `fd2078e66ed0edf014a7473371172546ff14a2d906512f9e888fe62acf378763`

This is an exact Sargo-template copy. Its header says it was generated
from Android `ueventd.rc`.

The exact generator invocation and Android source revision have not
been established. Some rules grant broad device-node permissions, so
the file should eventually be regenerated and reviewed specifically
for `gta4lwifi`.

### Repowerd `config-default.xml`

Path:

`overlay/system/usr/share/repowerd/device-configs/config-default.xml`

- SHA-256:
  `866455fd42bc1f2bf779d54e35bd649d34ce26fcb8730ce647c79b1a054f563c`

This is an exact Sargo-template copy derived from a Google Pixel
3a/Sargo Android resource overlay.

Related upstream source:

<https://github.com/LineageOS/android_device_google_bonito/blob/lineage-19.1/sargo/overlay/frameworks/base/core/res/res/values/config.xml>

It still contains Pixel-specific values including `g020g` and
`com.google.sensor.double_touch`. These values have not been claimed as
correct for the Samsung SM-T500 and require device-specific review.

## Inherited panic telnet script

Path:

`ramdisk-overlay/scripts/panic/panic/telnet`

- SHA-256:
  `1c917fbd527c187f7b1b6d991a2c34cb14dbd5f16c743f358facd68f264cdcdd`
- Origin: exact Sargo-template copy

The script configures USB RNDIS, starts DHCP, and launches a BusyBox
telnet server providing `/bin/sh` without authentication.

The inherited path contains a duplicated `panic` directory. The
standard Halium location is:

`/scripts/panic/telnet`

The reviewed recovery image did not contain this overlay script. The
nested copy appears not to be a normal panic-handler entry, but path
placement must not be treated as a security boundary.

Do not move or enable this script without an explicit security and
physical-access decision. Moving it to the normal Halium location would
create new runtime behavior and could expose an unauthenticated root
shell over USB during a boot panic.

Upstream reference:

<https://github.com/Halium/initramfs-tools-halium/blob/halium/scripts/panic/telnet>

## Licensing boundary

Original work authored specifically for this repository is covered by
the repository's GPL-3.0 license.

Imported Android, Halium, UBports, LineageOS, mer-hybris, Linux,
Samsung, Qualcomm, and other third-party files remain under their
respective upstream licenses and notices.

Presence in another public port repository is evidence of provenance,
not by itself proof that every redistribution obligation has been
satisfied.

No proprietary camera libraries, compiled D1AA `libcameraservice.so`,
private runtime logs, credentials, device-user data, or authentication
tokens are included in the camera source publication.
