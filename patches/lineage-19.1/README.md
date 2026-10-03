# LineageOS 19.1 Android-base patches

These patches preserve the source changes used by the SM-T500
`gta4lwifi` Wi-Fi Ubuntu Touch / Halium 12 port. They do not claim or add
support for an LTE model.

The device repositories were taken from the LineageOS `lineage-20`
branches because those were the available SM-T500 trees. The patches in
`android_device_samsung_gta4l-common/` apply in order on top of:

`e09239b41da278e3f0417f46e36de897fa4d3076`

They record:

1. the corrected boot ramdisk offset and Android 12 product inheritance;
2. Android 12 audio HAL 7.0 compatibility; and
3. the legacy Qualcomm UM SELinux types required by this Wi-Fi build.

Apply them from `device/samsung/gta4l-common` with:

```bash
git am /path/to/ubuntu-touch-samsung-gta4lwifi/patches/lineage-19.1/android_device_samsung_gta4l-common/*.patch
```

The exact project selection used by the preserved tree is recorded in
`../../manifests/lineage-19.1-gta4lwifi.xml`.
