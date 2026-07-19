# Ubuntu Touch for Samsung Galaxy Tab A7 Wi-Fi (SM-T500)

Experimental Ubuntu Touch 24.04 / Halium 12 port for the Samsung Galaxy
Tab A7 Wi-Fi, model **SM-T500**, codename **gta4lwifi**.

> [!WARNING]
> This project is only for the Wi-Fi SM-T500 (`gta4lwifi`). Do not flash
> these files on the LTE SM-T505, SM-T505C, SM-T505N, SM-T507, or other
> `gta4l` models. This remains an experimental community port and is not
> yet available through the UBports Installer.

## Device and base

- Device: Samsung Galaxy Tab A7 Wi-Fi
- Model: SM-T500
- Codename: gta4lwifi
- SoC: Qualcomm SM6115 / Snapdragon 662
- Architecture: arm64 / aarch64
- Android base: Android 12 / LineageOS 19.1-style vendor
- Halium: 12
- Ubuntu Touch: 24.04 Noble
- Kernel: Samsung/QCOM Linux 4.19.300

The device must have a compatible Android 12 vendor and ODM base. The
userdata filesystem must be ext4, not F2FS.

## Current status

Status as of July 17, 2026:

| Component | Status |
| --- | --- |
| Boot and Lomiri | Working |
| Display, touch, and hardware composition | Working |
| Wi-Fi | Working |
| Speaker audio | Working |
| Microphone | Working |
| GNSS/GPS | Working |
| Sensors and rotation | Working |
| Still photos | Working with port-specific fixes |
| Video recording | Working through a custom recorder path; stock Camera video remains unresolved |
| Bluetooth | Experimental work in progress; VHCI, Bluebinder, BlueZ, MGMT, L2CAP, and HID bring-up are under active testing |
| About Device page | Temporary port-specific workaround in use |

Bluetooth changes are intentionally marked experimental. Some diagnostic
fences and logging remain in the kernel while unsafe callback paths are
being isolated.

## Kernel source

The port uses the `gta4lwifi-halium12` branch of:

<https://github.com/jojobear691/kernel-samsung-sm6115-halium12>

The branch contains the current Ubuntu Touch configuration and
experimental Bluetooth/VHCI work.

## Repository layout

- `deviceinfo` — device and build configuration
- `overlay/` — Ubuntu Touch and Android-container overrides
- `ramdisk-overlay/` — boot ramdisk additions
- `ramdisk-recovery-overlay/` — recovery additions
- `prebuilt/gta4lwifi/` — required device-tree images
- `build.sh` — entry point for UBports community-port build tools
- `.gitlab-ci.yml` — community-port CI configuration

Downloaded repositories, build outputs, OTA files, installation images,
local backups, and test work directories are intentionally excluded from
Git.

## Camera source and artifact provenance

The known-working camera-service changes are published as a
source-only record. The text patch does not run automatically or
modify a device, and the compiled `libcameraservice.so` is not
included.

Droidmedia remains part of the known-working Ubuntu Touch camera
path for this device.

- [Camera source record](patches/frameworks-av/README.md)
- [Camera security notes](patches/frameworks-av/SECURITY.md)
- [Exact camera source manifest](provenance/frameworks-av-d1aa-source-manifest.txt)
- [Port source and artifact provenance](docs/PROVENANCE.md)
- [Published checksums](checksums/)

## Building

On a supported Ubuntu build host:

    git clone https://github.com/jojobear691/ubuntu-touch-samsung-gta4lwifi.git
    cd ubuntu-touch-samsung-gta4lwifi
    ./build.sh

The build script downloads the UBports Halium generic adaptation build
tools and clones the public kernel branch declared in `deviceinfo`.

Build and installation procedures are still being documented and tested.
Do not flash generated images without understanding Samsung Download Mode,
the device partition layout, and the required Android 12 base.

## Installation safety

- Back up all important data before flashing.
- Confirm the tablet is exactly an SM-T500/gta4lwifi.
- Use Samsung Download Mode and Heimdall for Samsung partition flashing.
- Do not substitute images from LTE gta4l models.
- Expect installation to erase data.
- This software is provided without warranty; you accept the risk of
  device damage or data loss.

A tested release package and complete installation guide will be published
separately from the Git source after the current state has been assembled
and verified.

## Credits

This work builds on projects and prior work from:

- [UBports](https://ubports.com/)
- [Halium](https://halium.org/)
- [LineageOS](https://lineageos.org/)
- [argosphil/aurora](https://github.com/argosphil/aurora)
- The Linux, BlueZ, libhybris, and wider mobile Linux communities

## License

Original work in this repository is licensed under GPL-3.0. Files or
binary artifacts originating from other projects remain subject to their
respective upstream licenses.
