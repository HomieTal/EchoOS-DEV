# echo-boot

Status: **Step 2 — payload populated (not active).** Boot assets, live initramfs
config, and package manifests exist in this component. `profile/` remains the
only active ArchISO profile; no assembly is performed and profile parity is not
established. This is a structural separation, not a bootloader migration.

## Responsibilities

- **UEFI live boot (systemd-boot):** `config/efiboot/loader/loader.conf` and
  `config/efiboot/loader/entries/01-archiso-linux.conf`,
  `02-archiso-speech-linux.conf`, `03-archiso-memtest86+x64.conf`.
- **BIOS live boot (Syslinux):** `config/syslinux/syslinux.cfg` and the
  included `archiso_*.cfg` files plus `splash.png`.
- **Kernel/initramfs entries:** Defined by the systemd-boot/Syslinux entries.
- **Kernel parameters:** As specified in the entry files (unchanged).
- **Boot menu:** Titles and menu structure preserved exactly.
- **ArchISO initramfs config:** `config/initramfs/archiso.conf`
  (`/etc/mkinitcpio.conf.d/archiso.conf`).
- **Boot artwork:** `config/syslinux/splash.png`.
- **Boot-related packages:** Declared in `packages/packages.x86_64` and
  `packages/packages.aarch64`.

## Live UEFI and BIOS paths

| Path | Purpose | Current profile |
| --- | --- | --- |
| `config/efiboot/loader/` | systemd-boot loader config | `profile/efiboot/loader/` |
| `config/efiboot/loader/entries/` | Kernel/initramfs/menu entries | `profile/efiboot/loader/entries/` |
| `config/syslinux/` | Syslinux BIOS/legacy boot | `profile/syslinux/` |
| `config/initramfs/archiso.conf` | ArchISO mkinitcpio drop-in | `profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf` |
| `config/grub/` | Retained inactive GRUB assets | `profile/grub/` |

The current boot modes remain `bios.syslinux` and `uefi.systemd-boot` as set in
`profile/profiledef.sh`. GRUB is not an active boot mode; `config/grub/` is
carried for parity only. No rEFInd boot mode is added.

## Files owned by Echo Boot

All files below are copied from the existing profile with contents and
permissions preserved. They are source configuration (and one binary asset),
not generated artifacts.

| Component path | Source path | Profile destination | Scope |
| --- | --- | --- | --- |
| `config/efiboot/loader/loader.conf` | `profile/efiboot/loader/loader.conf` | `efiboot/loader/loader.conf` | BOOT-LIVE |
| `config/efiboot/loader/entries/01-archiso-linux.conf` | `profile/efiboot/loader/entries/01-archiso-linux.conf` | `efiboot/loader/entries/01-archiso-linux.conf` | BOOT-LIVE |
| `config/efiboot/loader/entries/02-archiso-speech-linux.conf` | `profile/efiboot/loader/entries/02-archiso-speech-linux.conf` | `efiboot/loader/entries/02-archiso-speech-linux.conf` | BOOT-LIVE |
| `config/efiboot/loader/entries/03-archiso-memtest86+x64.conf` | `profile/efiboot/loader/entries/03-archiso-memtest86+x64.conf` | `efiboot/loader/entries/03-archiso-memtest86+x64.conf` | BOOT-LIVE |
| `config/syslinux/syslinux.cfg` | `profile/syslinux/syslinux.cfg` | `syslinux/syslinux.cfg` | BOOT-LIVE |
| `config/syslinux/archiso_head.cfg` | `profile/syslinux/archiso_head.cfg` | `syslinux/archiso_head.cfg` | BOOT-LIVE |
| `config/syslinux/archiso_pxe.cfg` | `profile/syslinux/archiso_pxe.cfg` | `syslinux/archiso_pxe.cfg` | BOOT-LIVE |
| `config/syslinux/archiso_pxe-linux.cfg` | `profile/syslinux/archiso_pxe-linux.cfg` | `syslinux/archiso_pxe-linux.cfg` | BOOT-LIVE |
| `config/syslinux/archiso_sys.cfg` | `profile/syslinux/archiso_sys.cfg` | `syslinux/archiso_sys.cfg` | BOOT-LIVE |
| `config/syslinux/archiso_sys-linux.cfg` | `profile/syslinux/archiso_sys-linux.cfg` | `syslinux/archiso_sys-linux.cfg` | BOOT-LIVE |
| `config/syslinux/archiso_tail.cfg` | `profile/syslinux/archiso_tail.cfg` | `syslinux/archiso_tail.cfg` | BOOT-LIVE |
| `config/syslinux/splash.png` | `profile/syslinux/splash.png` | `syslinux/splash.png` | BOOT-LIVE |
| `config/grub/grub.cfg` | `profile/grub/grub.cfg` | `grub/grub.cfg` | BOOT-INACTIVE |
| `config/grub/loopback.cfg` | `profile/grub/loopback.cfg` | `grub/loopback.cfg` | BOOT-LIVE |
| `config/initramfs/archiso.conf` | `profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf` | `airootfs/etc/mkinitcpio.conf.d/archiso.conf` | LIVE-EXCLUDED |

Assembly order for these overlays is defined in `build/config/overlays.tsv`.

## Package declarations

`packages/packages.x86_64`:

```text
edk2-shell
efibootmgr
grub
memtest86+
memtest86+-efi
refind
syslinux
```

`packages/packages.aarch64`:

```text
edk2-shell
efibootmgr
grub
stubble
```

These are the Boot-owned packages from `build/config/legacy-package-owners.tsv`.
No packages were added or removed. `refind` is present but the profile does not
select a rEFInd boot mode (rEFInd is out of scope for Step 2).

## Dependencies and relationships

- **Echo Core:** Boot consumes the kernel, firmware, initramfs tooling, and
  live root. Core owns most filesystem/network/system services.
- **Echo Install:** The installed-system bootloader is currently controlled by
  Calamares via `profile/airootfs/etc/calamares/modules/bootloader.conf` and
  the `calamares` workflow. That remains under Echo Install; Echo Boot does not
  own installed-system GRUB selection.
- **Shared infrastructure:** `profile/profiledef.sh` defines boot modes and
  `file_permissions`, and `build/` assembly infrastructure remains shared.
  Package lists are generated; manifests are component-owned inputs only when
  populated.

## ArchISO relationship

This component provides live boot configuration for systemd-boot and Syslinux
as used by ArchISO 91. The `mkinitcpio-archiso` package (owned by Echo Core in
the current ownership map) and ArchISO hooks remain outside this component.
Kernel parameters and menu structure are preserved exactly.

## Files intentionally retained in shared infrastructure

- `profile/profiledef.sh` — boot mode selection, ISO metadata, permissions
- `profile/pacman.conf.in` and package-list assembly
- `profile/pacman.conf`, `profile/packages.*` remain generated/inputs as before
- ArchISO tooling and any host dependencies

## rEFInd

rEFInd support is not implemented in Step 2. The `refind` package exists in
the x86_64 Boot manifest because it is already declared by the project and owned
by Boot; the current boot modes are unchanged.

## Assembly

When implemented, the assembler will overlay files via `build/config/overlays.tsv`.
No profile is generated in Step 2. `build/assemble.sh` is still a stub and
`build/generated/` is empty.

## Validation (Step 2)

`./build/validate.sh` was updated for Step 2 to check Boot payloads, package
manifests, permissions/content against sources, ownership coverage, and that
`profile/` is unchanged relative to `build/config/profile-baseline.tsv`. Parity
is **not established**.

## Intentionally out of scope for Step 2

- Bootloader migration or activation changes
- Kernel/initramfs changes
- rEFInd integration
- Boot menu redesign or branding changes
- Installed-system bootloader changes
- Building an ISO or boot tests
- Populating echo-install or echo-core
