# gta4lwifi libcameraservice D1AA source patch

This directory records the Android `frameworks/av` source changes used
to build the known-working D1AA camera library for the Samsung Galaxy
Tab A7 Wi-Fi (`SM-T500`, codename `gta4lwifi`).

The patch is only a text record. It does not run automatically, modify
a device, or contain the compiled camera library.

## Source baseline

- Project: `LineageOS/android_frameworks_av`
- Branch: `lineage-19.1`
- Base commit: `8ad4e1d710fab315ff7ce461eed1efa60f282828`
- Device: Samsung SM-T500 (`gta4lwifi`)
- Halium base: Halium 12
- Ubuntu Touch release: 24.04
- Files changed: 5
- Insertions: 429
- Deletions: 11

This is a device compatibility change. It is not intended as a general
Android camera patch.

## Known-working build identity

The verified source produced a stripped `libcameraservice.so` with:

- SHA-256: `d1aa44ea12356830e61fe83fa9fd177244c91721d3730cd8aacc40408ee4c3bf`
- ELF Build ID: `d9ec4ea768df76fdcfa2beb89abee1ba`

The compiled library is intentionally not included.

Exact source identities and checksums are recorded in:

- `../../provenance/frameworks-av-d1aa-source-manifest.txt`
- `../../checksums/SHA256SUMS`

## Camera trust bridge

`CameraService.cpp` adds the Unix-domain socket expected by the Ubuntu
Touch camera trust-store service.

Endpoint:

`/dev/socket/camera_service/camera_service_to_trust`

The implementation was adapted from earlier Ubuntu Touch and Halium
camera-service work. Its origins are recorded in the provenance
manifest.

## Ubuntu Touch client compatibility

The source recognizes the Ubuntu Touch `hybris` and `droidmedia`
camera clients for the device's expected Android UID.

This allows the Ubuntu Touch camera stack to open the camera when
Android considers the client to be in the background. Normal camera
permission and sensor-privacy checks remain.

Droidmedia is required for the known-working camera configuration. This
patch does not remove or replace droidmedia.

## Droidmedia preview workaround

For the `droidmedia` client, the API1 preview path avoids creating the
JPEG/BLOB still-capture stream during preview.

On this device, combining that stream with preview can make the
Qualcomm CamX implementation select an incompatible configuration and
crash.

## Capture sequencing workaround

The capture sequence avoids calling the shutter notification path while
holding an input mutex. This prevents a lockup between shutter handling
and the JPEG callback on this port.

## Experimental properties

The source contains additional diagnostic workarounds. Every property
defaults to `false`.

| Property | Effect when explicitly enabled |
| --- | --- |
| `debug.taba7.no_api1_jpeg_stream` | Disables the API1 JPEG stream |
| `debug.taba7.drop_blob_stream_v2` | Drops a BLOB stream during stream creation |
| `debug.taba7.drop_blob_stream` | Drops a BLOB stream in another creation path |
| `debug.taba7.force_global_blob_filter` | Filters BLOB streams before HAL configuration |
| `debug.taba7.force_hidl_blob_filter` | Filters BLOB streams before HIDL configuration |

These properties should remain disabled unless someone is deliberately
diagnosing a camera-stream problem.

## Applying the source record

Start from the exact `frameworks/av` base commit listed above. The text
record can then be applied with `git apply` inside that source tree.

Applying it only changes source files. A normal Android build is still
required to produce a library or system image.

Do not apply it to an unrelated Android version or commit without
reviewing and adapting the changes.

## Licensing and attribution

The changed Android files retain their upstream copyright notices and
Apache-2.0 licensing.

The port repository's root license does not replace the licenses of
imported Android source material.

No proprietary vendor camera blobs, private runtime logs, credentials,
or compiled `libcameraservice.so` are included here.
