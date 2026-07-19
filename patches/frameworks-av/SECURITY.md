# Security notes for the D1AA camera source patch

This document describes security and compatibility tradeoffs in the
device-specific `libcameraservice` changes.

The patch is known to work on the Samsung SM-T500 Ubuntu Touch port,
but some parts should be hardened before treating the implementation as
a general-purpose Android camera-service change.

## Camera trust socket permissions

The patch creates:

- `/dev/socket/camera_service`
- `/dev/socket/camera_service/camera_service_to_trust`

The current implementation assigns world-accessible permissions to the
directory and socket endpoint.

The server uses `SO_PEERCRED` to obtain the connecting process UID and
stores trust-agent connections by UID. However, it does not verify the
agent's executable identity, SELinux domain, AppArmor profile, package,
or dedicated service account.

Consequences include:

- another process using the expected UID could attempt to register as a
  trust agent;
- the first or replacement connection behavior requires careful review;
- broad filesystem permissions expose more of the endpoint than needed.

Recommended hardening includes:

- create the socket through Android init where possible;
- assign a dedicated owner and group;
- use permissions such as `0660` instead of world-writable permissions;
- validate the expected peer UID and security domain;
- reject or safely replace duplicate agent connections;
- close and remove dead connections promptly.

## Trust protocol behavior

The protocol writes a native request structure and synchronously reads a
32-bit answer.

The current implementation does not provide:

- a protocol version;
- framing independent of the native C++ structure layout;
- explicit handling for partial reads or writes;
- a response timeout;
- cancellation when the peer stops responding.

A connected but unresponsive agent could therefore block a camera
connection attempt inside cameraserver.

Recommended hardening includes a versioned fixed-width protocol,
complete read/write loops, polling with a bounded timeout, and explicit
disconnect recovery.

## Fail-open and fail-closed behavior

Trust enforcement is enabled only when:

`/sys/module/binder/parameters/global_pid_lookups`

exists and begins with `Y`.

When that kernel support is unavailable, the trust check returns
success so the Ubuntu Touch camera remains usable. This is fail-open
behavior.

When kernel support is enabled, a missing agent, communication error,
explicit denial, or malformed response can prevent a camera connection.
That path is effectively fail-closed.

Both behaviors are intentional compatibility choices and should be
documented for downstream builds.

## Ubuntu Touch background-client exception

The patch recognizes only clients named `hybris` or `droidmedia` with
Android UID `32011`.

For that combination it bypasses Android's active-UID and currently
allowed-device-user checks. This was necessary for the Ubuntu Touch
camera stack on the tested port.

The exception does not remove the ordinary camera permission check or
the sensor-privacy check.

Security assumptions:

- UID `32011` must remain assigned only to the intended Ubuntu Touch
  compatibility environment;
- untrusted applications must not be allowed to share that UID;
- client-name checks alone must not be considered authentication;
- changing the device's UID mapping requires reviewing this exception.

## Droidmedia preview workaround

The droidmedia-specific preview change avoids adding the API1
JPEG/BLOB still stream during preview. It works around a device-specific
Qualcomm CamX crash.

This changes available stream behavior for that exact client. It should
not be enabled globally without testing still capture, preview, video,
camera switching, flash, and recovery after a camera-service restart.

## Experimental debug properties

The following properties default to `false`:

- `debug.taba7.no_api1_jpeg_stream`
- `debug.taba7.drop_blob_stream_v2`
- `debug.taba7.drop_blob_stream`
- `debug.taba7.force_global_blob_filter`
- `debug.taba7.force_hidl_blob_filter`

Enabling them can remove JPEG/BLOB streams or alter the configuration
sent to the camera HAL. That can break photography, return invalid
stream identifiers, confuse framework state, or cause provider errors.

They should remain disabled in normal builds unless being used for a
controlled diagnostic test.

## Logging and privacy

The added messages can include client names, UIDs, PIDs, camera IDs,
stream dimensions, formats, and usage flags.

They do not intentionally log image data or credentials. Downstream
builds should still reduce warning-level diagnostic logging after the
port stabilizes.

## Publication boundary

This directory publishes source changes, provenance, and checksums only.

It does not include:

- proprietary Samsung or Qualcomm camera libraries;
- the compiled D1AA `libcameraservice.so`;
- private runtime logs;
- device-user data;
- authentication credentials.

Patch reviewed by this document:

`343c520a24d09745fe0eba3af370aab979f6972919c65473b7fb79f37a0616ee`
