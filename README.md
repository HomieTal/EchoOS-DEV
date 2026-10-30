# Echo OS

An Arch Linux–based live system with a KDE Plasma desktop and a graphical
Calamares installer, built from independently maintained components.

## Overview

- **Live environment**: KDE Plasma 6 on Wayland (XWayland for X11 apps),
  autologged in as the `archiso` user through SDDM.
- **Installer**: [Calamares](https://calamares.io/) (stock branding) launched
  from the "Install Echo OS" desktop shortcut and autostarted once in the live
  session.
- **Installation method**: copy of the live squashfs to the target disk via
  `unpackfs` (offline-capable; no package downloads required).
- **Bootloaders**: rEFInd for UEFI (live medium and installed system), Syslinux
  for BIOS live boot.
- **Local packages**: Calamares is built from source and served via a local
  `[echo]` repository in `packages/`.

## Components

| Component | Owns |
| --- | --- |
| `components/echo-core` | kernel, firmware, base system, services, networking, live account |
| `components/echo-desktop` | Plasma, SDDM, session/branding defaults, wallpapers, desktop apps |
| `components/echo-install` | Calamares, modules, installer autostart/shortcut, installer policy |
| `components/echo-boot` | rEFInd, EFI payloads, Syslinux, boot menus |
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

1. Boot the ISO (UEFI or BIOS).
2. In the Plasma live session, use the **Install Echo OS** desktop shortcut
   (the installer also autostarts once).
3. Follow the Calamares wizard (locale, keyboard, partitioning, user creation).
4. Reboot into the installed system (SDDM login, Plasma session).

## Notes

- Calamares uses the stock `default` branding component for the installer UI;
  Echo OS branding is applied to the desktop (look-and-feel, wallpaper, SDDM
  background).
- The live user is removed from the installed target; the account you create
  during installation is the only user.
- The target's pacman package databases are refreshed during first boot / via
  post-install cleanup; with no network the databases remain empty but the
  installed system is already complete.
