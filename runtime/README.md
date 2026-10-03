# Proven live runtime source

`proven-live/` is a sanitized, text-only source snapshot recovered from
the working SM-T500 `gta4lwifi` Wi-Fi tablet on October 3, 2026. The
directory layout mirrors the absolute paths used on the device.

This is a provenance record, not a one-command installer. A file being
present on the working tablet does not mean it is independently portable
or safe to enable on another device. Review service ordering, paths, and
dependencies before packaging it into a clean image.

The `phablet` name in paths and service commands is Ubuntu Touch's standard
system account, not private owner information.

## Included source

- Wi-Fi, audio, sensor, scheduling, Bluetooth, UI, and camera shell scripts;
- their system and user systemd units/drop-ins;
- root-owned GPS and Android boot-completion helpers that wait for the custom
  Android container without embedding or prompting for a sudo password;
- a fake-udev-trigger override matching the deliberately disabled stock
  Android-container launcher;
- a persistent `schedutil` CPU-frequency policy and cold-boot ordering that
  starts location and Android boot-completion only after the proven GPS and
  custom-container readiness service;
- the current Camera application QML overrides;
- the text AppArmor override used with the patched media-hub service; and
- the camera trust-agent restart drop-in added after proving an EOF busy-loop
  when the delayed camera fix replaced `cameraserver`.

The trust restart was verified by a successful end-to-end service restart,
normal sleeping trust-agent threads, less than one percent CPU usage, a live
`media.camera` service, and both camera IDs registered.

## Deliberately excluded

No raw logs, backups, SSH material, credentials, serial numbers, device-user
data, or private host paths are included. Compiled and proprietary-dependent
artifacts also remain outside Git, including:

| Runtime dependency | Preserved SHA-256 |
| --- | --- |
| `ut_scheduling_policy_stub` | `9916768ca5c3a01a75f8ecedddf89522314275a3ccb0bcac5a700367d87bfc43` |
| `ut_camera_binder_stubs_grant_v10` | `ed8df9c8a9c26bbe09a83f93b87368a8ef9880a40698f3899beaa33a736d8f29` |
| `cameraserver-los` | `aeac335ad657c8007aa1666786f9725572da96fc4508dc99d9b1800452cf8d6c` |
| photo camera-service library | `389eaa4d3312befd4f1054905a63e5883b13c072f3e3668a642c02178d99f3eb` |
| earlier trust-agent camera-service library | `6592667490431d1d3fbfe670fa1538b6c690b83303d53cc45f108a5e00afc0cd` |

Other referenced runtime material, such as the framework island, audio policy
files, patched media-hub binary, and About-page workaround directory, is not
published until its source and redistribution status are established.

This work applies only to the Wi-Fi SM-T500 (`gta4lwifi`).
