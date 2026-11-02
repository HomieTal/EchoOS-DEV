# MAD Installer — Dependencies

## Runtime

| Dependency | Role | Source |
| --- | --- | --- |
| `calamares` 3.4.2 | installation engine, UI runtime | locally built (`packages/PKGBUILD`, artifact in `packages/`) |
| `kconfig`, `kcrash`, `kpackage` | KF6 libraries calamares links against; declared explicitly because the local calamares package has an incomplete depends array | Arch packages |
| `kpmcore` | partitioning backend of the partition module | Arch package (calamares depends) |
| `polkit` / `pkexec` | privilege escalation (only path used) | base |
| `plasma-workspace` (session) | live Plasma Wayland session hosting the installer | echo-desktop |
| `sddm` | display manager configured for the target | echo-desktop |
| `refind` | UEFI bootloader installed into the target ESP | echo-boot |
| `grub` | BIOS (legacy) bootloader path, x86_64 only | echo-boot (live) |
| `libpwquality` | password quality checks in the users module | calamares depends |

## Build

| Dependency | Role |
| --- | --- |
| `extra-cmake-modules`, `ninja`, `qt6-tools`, `qt6-translations`, `libglvnd` | calamares 3.4.2 build (`packages/PKGBUILD`) |
| `librsvg` (`rsvg-convert`) | regenerating branding PNGs from `echo-mark.svg` |
| `makepkg` | building the `mad-installer` package (`packaging/PKGBUILD`) |

## External utilities used at install time

- `refind-install` (rEFInd), `grub-install` / `grub-mkconfig` (BIOS path),
  `findmnt`, `lsblk`, `blkid` — used by `mad-refindconf-write`.
- `xhost` — Xwayland grant in the launcher (best-effort, optional).

## Calamares modules required (verified against installed 3.4.2)

`welcome, locale, keyboard, partition, users, summary, partition, mount,
unpackfs, shellprocess, removeuser, machineid, localecfg, fstab, initcpiocfg,
initcpio, displaymanager, hwclock, services-systemd, packages, umount,
finished`

The `bootloader` module is intentionally unused.

## Replacement candidates (future engine, see ROADMAP.md)

| Current | Candidate | Notes |
| --- | --- | --- |
| Calamares runtime | custom Qt/QML frontend over a MAD Installation API | frontend seam already isolated |
| kpmcore partitioning | libblockdev / parted / sfdisk behind a plan/commit API | must preserve preview-before-commit |
| unpackfs | image-based deployment | biggest reliability win |
| rEFInd/GRUB shell glue | MAD boot-manager component | ESP layout contract must be kept |

## Explicitly unsupported

- **aarch64**: no installer (empty `packages/packages.aarch64`; PKGBUILD
  arch is x86_64 only). Do not advertise ARM support.
- Network-based installation: offline by design.
