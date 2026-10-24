# Step 2 report — Echo Boot separation

Status: **Step 2 complete.** Boot assets, live initramfs configuration, and
package manifests exist under `components/echo-boot/`. No profile files were
moved, modified, or overwritten. The active `profile/` is unchanged. No ISO was
built and no boot/install tests were performed. Profile parity is **not
established**.

## Files added or changed

### New Boot payload files

All payload files were copied byte-for-byte from the existing profile with
`cp -a`; permissions are preserved. They are source configuration/assets, not
generated artifacts.

| File | Type | Source |
| --- | --- | --- |
| `components/echo-boot/config/efiboot/loader/loader.conf` | config | `profile/efiboot/loader/loader.conf` |
| `components/echo-boot/config/efiboot/loader/entries/01-archiso-linux.conf` | config | `profile/efiboot/loader/entries/01-archiso-linux.conf` |
| `components/echo-boot/config/efiboot/loader/entries/02-archiso-speech-linux.conf` | config | `profile/efiboot/loader/entries/02-archiso-speech-linux.conf` |
| `components/echo-boot/config/efiboot/loader/entries/03-archiso-memtest86+x64.conf` | config | `profile/efiboot/loader/entries/03-archiso-memtest86+x64.conf` |
| `components/echo-boot/config/syslinux/syslinux.cfg` | config | `profile/syslinux/syslinux.cfg` |
| `components/echo-boot/config/syslinux/archiso_head.cfg` | config | `profile/syslinux/archiso_head.cfg` |
| `components/echo-boot/config/syslinux/archiso_pxe.cfg` | config | `profile/syslinux/archiso_pxe.cfg` |
| `components/echo-boot/config/syslinux/archiso_pxe-linux.cfg` | config | `profile/syslinux/archiso_pxe-linux.cfg` |
| `components/echo-boot/config/syslinux/archiso_sys.cfg` | config | `profile/syslinux/archiso_sys.cfg` |
| `components/echo-boot/config/syslinux/archiso_sys-linux.cfg` | config | `profile/syslinux/archiso_sys-linux.cfg` |
| `components/echo-boot/config/syslinux/archiso_tail.cfg` | config | `profile/syslinux/archiso_tail.cfg` |
| `components/echo-boot/config/syslinux/splash.png` | binary asset | `profile/syslinux/splash.png` |
| `components/echo-boot/config/grub/grub.cfg` | inactive config | `profile/grub/grub.cfg` |
| `components/echo-boot/config/grub/loopback.cfg` | config | `profile/grub/loopback.cfg` |
| `components/echo-boot/config/initramfs/archiso.conf` | initramfs config | `profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf` |

The existing `.gitkeep` placeholders under `config/`, `hooks/`, and `packages/`
were retained, not created by Step 2.

### New component metadata

| File | Type | Notes |
| --- | --- | --- |
| `components/echo-boot/packages/packages.x86_64` | package manifest | 7 Boot packages, sorted |
| `components/echo-boot/packages/packages.aarch64` | package manifest | 4 Boot packages, sorted |
| `components/echo-boot/hooks/README.md` | doc | Records that no boot-specific profile hooks exist |
| `build/config/profile-baseline.tsv` | preservation baseline | Path/type/mode/size plus content hashes for non-sensitive profile files; sensitive files are metadata-only |
| `docs/step-2-echo-boot-report.md` | doc | This report |

### Existing files changed

| File | Change |
| --- | --- |
| `components/echo-boot/README.md` | Replaced Step 1 placeholder with Step 2 responsibilities, file/package ownership, dependencies, interfaces, rEFInd exclusion, and assembly notes |
| `components/README.md` | Status updated for populated Echo Boot |
| `build/README.md` | Status, baseline, and validator behavior updated |
| `build/config/README.md` | Added profile baseline and component-manifest status |
| `build/validate.sh` | Extended with Step 2 Boot, package, baseline, and ownership checks |
| `build/assemble.sh` | Status strings updated; remains a non-generating stub |
| `docs/step-1-component-map.md` | Status note updated without changing ownership data |
| `docs/step-1-assembly-contract.md` | Status/current-input notes updated; contract unchanged |
| `docs/step-1-parity-check.md` | Updated current parity blockers; result remains not established |

No existing files were deleted. No profile files were changed.

## Files intentionally not moved

- `profile/profiledef.sh` — shared boot-mode selection, ISO metadata, and
  `file_permissions`.
- `profile/pacman.conf.in`, `profile/pacman.conf`, `profile/packages.*`, and
  `profile/bootstrap_packages` — shared package/build infrastructure.
- `profile/airootfs/etc/calamares/modules/bootloader.conf` and the Calamares
  workflow — installed-system bootloader behavior remains Echo Install.
- `mkinitcpio-archiso`, ArchISO hooks, kernels, firmware, and generated
  kernel/initramfs artifacts — not manually copied; they remain package- or
  build-generated.
- `profile/airootfs/etc/pacman.d/hooks/` and other live-root files — not
  boot-owned.
- Local repository/package build artifacts — not part of the live boot payload.

The GRUB files are retained as inactive assets for current-profile parity. GRUB
remains the installed-system bootloader selected by Calamares, not a live ISO
boot mode.

## Package declarations assigned

Boot-owned packages exactly as recorded in
`build/config/legacy-package-owners.tsv`:

- x86_64: `edk2-shell`, `efibootmgr`, `grub`, `memtest86+`, `memtest86+-efi`,
  `refind`, `syslinux` (7 packages).
- aarch64: `edk2-shell`, `efibootmgr`, `grub`, `stubble` (4 packages).

No package was added or removed. `refind` is present only because it is already
declared and Boot-owned; no rEFInd integration or boot mode was introduced.

## Live boot paths (unchanged)

- UEFI live boot: systemd-boot via `efiboot/loader/`.
- BIOS live boot: Syslinux via `syslinux/`.
- Active boot modes: `bios.syslinux` and `uefi.systemd-boot`, unchanged in
  `profile/profiledef.sh`.
- Kernel parameters, menu titles, and initramfs configuration are preserved
  byte-for-byte in the copied files.
- Installed-system bootloader: GRUB via Calamares, unchanged.

## Validation results

Command: `./build/validate.sh`

The validator checks:

- Required component structure and documentation.
- Every Boot-owned file in the ownership map exists and matches its legacy
  source by content and mode.
- The `components/echo-boot/` file set is exactly the mapped Boot payload plus
  component metadata; no unexpected files.
- Boot package manifests are valid, sorted, duplicate-free, and exactly match
  Boot-owned packages for each architecture.
- Package ownership is duplicate-free and no package is duplicated across
  component manifests for the same architecture.
- Ownership maps remain complete: every mapped source exists, every profile file
  and legacy package declaration is covered exactly once, owner values are
  valid, and future/destination paths are unique.
- All 106 profile files are present with unchanged metadata; non-sensitive
  content hashes also match the baseline. Sensitive files are metadata-only.
- `build/generated/` contains no generated profile.

Final result:

```text
STEP 2 VALIDATION: PASSED
PROFILE PARITY: NOT ESTABLISHED
```

No ISO was built, no boot/install test was performed, and no Git command was
used.

`./build/assemble.sh` was also run as a non-generating safety check. It exited
`2`, reported the missing Echo Core/Echo Install manifests and shared templates,
and wrote nothing. `build/generated/` still contains only `.gitkeep`.

## Outstanding blockers

- Echo Install and Echo Core have no payload yet (Steps 3 and 4).
- Only Echo Boot has package manifests; the complete package set cannot be
  assembled or compared yet.
- Shared templates are absent from `build/template/`.
- `build/assemble.sh` remains a non-generating stub; no generated profile exists.
- The known live/target exclude-list gaps are documented but unchanged.
- No generated-vs-legacy profile comparison has occurred.

## Rollback instructions

No profile rollback is needed: `profile/` was not modified. Because Git commands
are prohibited for this step, rollback is manual:

1. Remove the 15 new Boot payload files listed above and their now-empty
   `config/efiboot`, `config/syslinux`, `config/grub`, and `config/initramfs`
   directories. Do not remove the existing `.gitkeep` placeholders.
2. Remove `components/echo-boot/packages/packages.x86_64`,
   `components/echo-boot/packages/packages.aarch64`,
   `components/echo-boot/hooks/README.md`,
   `build/config/profile-baseline.tsv`, and
   `docs/step-2-echo-boot-report.md`.
3. Restore the previous contents of `components/echo-boot/README.md`,
   `components/README.md`, `build/README.md`, `build/config/README.md`,
   `build/validate.sh`, `build/assemble.sh`, `docs/step-1-component-map.md`,
   `docs/step-1-assembly-contract.md`, and `docs/step-1-parity-check.md` from a
   local backup.
4. Optionally run `./build/validate.sh` after restoring the Step 1 validator and
   structure. A partial rollback will correctly fail the Step 2 validator.

Do not restore the profile from this component: the active profile was never
changed and remains authoritative.
