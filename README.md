# Echo OS

An Arch Linux–based live system with the **Ash Desktop** (GNOME technology base) and the **MAD Installer**
(Calamares), built from independently maintained components.

Version 4.1 — image `2026.10.31`.

## Overview

- **Live environment**: the Ash Desktop session, autologged in as
  the `archiso` user through GDM.
- **Installer**: **MAD Installer**, a Calamares frontend with Echo OS branding.
  It is launched from the "MAD Installer" desktop shortcut and autostarts once
  in the live session.
- **Installation method**: copy of the live squashfs to the target disk via
  `unpackfs` (offline-capable; no package downloads required).
- **Bootloaders**: rEFInd for UEFI (live medium and installed system). The live
  medium is UEFI-only; the legacy Syslinux/BIOS live path is no longer built.
- **Local packages**: Calamares is built from source and served via a local
  `[echo]` repository in `packages/`.

## Components

| Component | Owns |
| --- | --- |
| `components/echo-core` | kernel, firmware, base system, services, networking, live account |
| `components/echo-boot` | rEFInd, EFI payloads, boot menus, live initramfs config |
| `components/ash-desktop` | Ash Desktop: branded session, GDM, session/branding defaults, wallpapers, desktop apps |
| `components/mad-install` | MAD Installer (Calamares), modules, installer autostart/shortcut, target boot policy |
| `build/` | assembly, shared templates, package merging, validation |

`build/assemble.sh` merges the components into `build/generated/profile`; the
legacy `profile/` directory is kept as a reference baseline and is not built
directly any more.

## Prerequisites

- Arch Linux host (or an environment with `archiso` and the packages listed in
  `build/template/bootstrap_packages`).
- `base-devel`, `archiso`, `squashfs-tools`, `mtools`, `dosfstools` and the
  packages required by `mkarchiso`.
- Root access (sudo) for `mkarchiso`.

## Building

```bash
# 1) Ensure the local package repository is up to date
repo-add packages/echo.db.tar.zst packages/*.pkg.tar.zst

# 2) Build the ISO (assembles the profile, runs mkarchiso, then repacks the
#    ESP payload with rEFInd)
./build.sh
```

The resulting ISO appears in `out/` (the build script never overwrites an
existing ISO).

## Installation

1. Boot the ISO in UEFI mode.
2. In the GNOME live session, use the **MAD Installer** desktop shortcut (the
   installer also autostarts once).
3. Follow the wizard (locale, keyboard, partitioning, user creation).
4. Reboot into the installed system (GDM login, Ash Desktop session).

## Notes

- MAD Installer carries the Echo OS installer branding; the desktop uses the
  Echo wallpaper, mark, and session branding.
- The live user is removed from the installed target; the account you create
  during installation is the only user.
- The target's pacman package databases are refreshed during first boot / via
  post-install cleanup; with no network the databases remain empty but the
  installed system is already complete.
