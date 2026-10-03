# Halium generic adaptation build-tool compatibility

`0001-gta4lwifi-halium12-build-compatibility.patch` records two host-build
changes used by the SM-T500 Wi-Fi port on top of UBports community-port
build tools commit `c48c8a8c65f19a025fbfa217b5fe8695c443ce59`:

- honor `deviceinfo_kernel_build_targets`, avoiding unsupported implicit
  kernel targets; and
- disable the ext4 `orphan_file` feature so images remain compatible with
  the older recovery `e2fsck` used by the tested installation path.

Apply it from the cloned `build/` directory with:

```bash
git apply /path/to/ubuntu-touch-samsung-gta4lwifi/patches/halium-generic-adaptation-build-tools/0001-gta4lwifi-halium12-build-compatibility.patch
```
