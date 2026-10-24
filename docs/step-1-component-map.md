# Step 1 component and ownership map

Status: **Step 1 baseline, updated in Step 2.** `profile/` is still the sole
active ArchISO profile. Echo Boot now has real component inputs; the component
ownership map in this document remains the complete baseline. Echo Core and
Echo Install are still skeletons. Profile parity is **not established**.

## Inventory baseline

| Item | Count |
| --- | ---: |
| Profile files and symlinks | 106 |
| Calamares configuration files | 18 |
| Boot files (`efiboot/`, `syslinux/`, `grub/`) | 14 |
| Unique package names | 159 |
| `packages.x86_64` entries | 156 |
| `packages.aarch64` entries | 145 |
| Legacy package-list duplicates | 0 |
| Ownership-map source rows | 118 (106 profile + 12 shared/package/docs) |

The machine-readable maps are:

- `build/config/legacy-file-owners.tsv`
- `build/config/legacy-package-owners.tsv`

Every profile file/symlink appears exactly once in the file map. Every package
in both architecture lists appears exactly once in the package map, with the
correct architecture flags. No duplicate proposed source paths or generated
destinations were found.

## File ownership totals

| Owner | Profile files | All source rows | Notes |
| --- | ---: | ---: | --- |
| `BOOT` | 15 | 15 | Live boot menus, initramfs config, inactive GRUB assets |
| `CORE` | 66 | 66 | Base system, desktop, services, live environment |
| `INSTALLER` | 19 | 21 | 18 Calamares files + live polkit rule; plus recipe/artifact |
| `SHARED` | 6 | 16 | Profile definition, pacman config, package lists, top-level build/docs |
| **Total** | **106** | **118** | |

`INSTALLER` has 21 total rows: 19 profile files, `packages/PKGBUILD`, and the
built Calamares package artifact. `SHARED` has 16 total rows: 6 profile files and
10 top-level package/build/documentation files.

## Current scope totals

| Scope | Rows | Meaning |
| --- | ---: | --- |
| `COMMON` | 33 | Live and currently retained in the installed target |
| `LIVE-EXCLUDED` | 20 | Live, explicitly excluded by the current Calamares exclude list |
| `LIVE-INTENDED` | 15 | Live-oriented but currently leaking into the target |
| `INSTALL-LIVE` | 18 | Calamares live configuration |
| `BOOT-LIVE` | 13 | Active live boot assets |
| `BOOT-INACTIVE` | 1 | `grub/grub.cfg`; retained but not an active boot mode |
| `BUILD` | 12 | Build inputs and documentation |
| `GENERATED` | 3 | `pacman.conf`, `packages.x86_64`, `packages.aarch64` |
| `ARTIFACT` | 3 | Built package/repository artifacts |
| **Total** | **118** | |

`LIVE-INTENDED` is deliberately not the same as `LIVE-EXCLUDED`. It records
current leakage so assembly does not silently "fix" behavior while establishing
parity.

The current exclude list has 25 entries. Five entries name paths that no longer
exist in the profile:

- `/etc/systemd/system/multi-user.target.wants/getty@tty1.service`
- `/etc/systemd/system/multi-user.target.wants/livecd-alsa-unmuter.service`
- `/root/.automated_script.sh`
- `/usr/local/bin/Installation_guide`
- `/etc/polkit-1/rules.d/49-nopasswd_global.rules`

They are recorded as-is. Step 1 does not edit the exclude list or remove stale
entries.

## Package ownership totals

| Owner | Packages | Notes |
| --- | ---: | --- |
| `BOOT` | 8 | `edk2-shell`, `efibootmgr`, `grub`, `memtest86+`, `memtest86+-efi`, `refind`, `stubble`, `syslinux` |
| `INSTALLER` | 1 | `calamares` (x86_64 only; intended live-only, payload currently copied to target) |
| `CORE` | 150 | Base/desktop/services/live tooling |
| `SHARED` | 0 | Shared build owns host/tooling inputs, not profile package declarations |
| **Total** | **159** | |

Current package scope:

- All 159 packages are live + target under current behavior. The target is
  populated by copying the live root and applying a file-level exclude list; no
  package is removed as a package.
- `calamares`, `livecd-sounds`, and `mkinitcpio-archiso` are **intended** to be
  live-only, but their package payloads are not fully removed by the current
  exclude list. Their configuration/files may be partially excluded; the
  package payload leaks remain recorded, not changed.

The package map records architecture presence explicitly. Examples of
architecture-only packages:

- x86_64 only: `amd-ucode`, `intel-ucode`, `memtest86+`, `memtest86+-efi`,
  `refind`, `syslinux`, `calamares`, several virtualization packages
- aarch64 only: `linux-dtbs`, `linux-firmware-qcom`, `stubble`

## Deliberate classification decisions

These are the cases most likely to be assigned by filename alone; the map uses
actual ownership and consumption:

| Item | Owner | Reason |
| --- | --- | --- |
| `calamares/modules/bootloader.conf` | Installer | It is Calamares configuration. It consumes Boot policy; Boot does not duplicate it. |
| `grub` package | Boot | Boot owns bootloader packages and policy. Installer invokes `grub-install` for the target. |
| `efibootmgr` | Boot | EFI boot entry policy/utility; consumed by Installer. |
| `refind` package | Boot | Optional Boot-owned bootloader. It is present but not selected; no boot-mode change. |
| `grub/grub.cfg` | Boot | Retained inactive asset. Current `bootmodes` do not include GRUB. |
| `profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf` | Boot | Live initramfs configuration. Core supplies the kernel and `mkinitcpio`. |
| `dosfstools`, `fatresize` | Core | Core filesystem tools. Installer may invoke them, but does not own them. |
| `mtools` | Core | Live FAT utility. Host `mtools` is a separate build prerequisite, not a Boot package declaration. |
| `squashfs-tools` | Core | Live/rescue tooling. Host `mksquashfs` is a separate build prerequisite. |
| `arch-install-scripts` | Core | Live/rescue tooling; not used by the Calamares offline flow. |
| `python` | Core | General runtime/tooling; not assigned to Installer solely for Calamares. |
| `polkit`, `polkit-gnome` | Core | Core authentication/desktop stack. The live Calamares polkit rule is Installer-owned. |
| `livecd-sounds`, `mkinitcpio-archiso`, `calamares` | Core/Installer, live-oriented | Their package payloads are not removed from the target by the current file-level exclude list; the intended live-only scope is recorded without changing behavior. |
| Package lists | Shared | They are generated assembly outputs, not component-owned source lists. |

## Empty directories

- `profile/airootfs/home/archiso/` — Core live user home; currently excluded.
- `profile/airootfs/etc/calamares/branding/` — Installer-owned and empty; stock
  Calamares branding is in use.

Neither is populated or changed in Step 1.

## Package manifest format

The proposed component manifests are per architecture:

```text
components/<component>/packages/packages.x86_64
components/<component>/packages/packages.aarch64
```

Rules:

- One package name per line; `#` comments and blank lines are ignored.
- Both architecture files must exist. An empty file is valid only when that
  component has no packages for that architecture.
- Duplicate package declarations across components for the same architecture
  are errors.
- During parity, the union of the three component manifests must exactly equal
  the legacy list for that architecture. Missing and extra packages both fail.
- Final lists are sorted deterministically; package **set** parity is required,
  not preservation of legacy line order.
- Package manifests describe live installation. They do not define target
  exclusions; the Installer-owned exclude list remains authoritative for that
  boundary.

No manifests are populated in Step 1, so package parity from components is
**not** established. The only verified package result is that the legacy lists
are fully represented in the ownership map.

## What this map does not prove

It does not prove that a generated profile matches `profile/`. It proves only
that the existing files and package declarations have a complete, unambiguous
ownership assignment and no duplicate proposed destinations. See
`docs/step-1-parity-check.md`.
