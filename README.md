# Echo OS

A minimal Arch Linux-based live system with a graphical Calamares installer.

## Overview
- **Live environment**: XFCE desktop, autologged in as the `archiso` user.
- **Installer**: [Calamares](https://calamares.io/) (stock branding) launched from the Applications menu ("Install System").
- **Installation method**: copy of the live squashfs to the target disk via `unpackfs` (offline-capable; no package downloads required).
- **Bootloaders**: BIOS (syslinux) and UEFI (systemd-boot) as shipped by the archiso releng profile.
- **Local packages**: Calamares is built from source and served via a local `[echo]` repository in `packages/`.

## Prerequisites
- Arch Linux host (or an environment with `archiso` and the packages listed in `profile/bootstrap_packages`).
- `base-devel`, `archiso`, `squashfs-tools` and the packages required by `mkarchiso`.

## Building
```bash
# 1) Ensure the local package repository is up to date
repo-add packages/echo.db.tar.zst packages/*.pkg.tar.zst

# 2) Render pacman.conf (uses an absolute path to packages/)
./scripts/render-pacman-conf.sh

# 3) Build the ISO
./build.sh
```
The resulting ISO will appear in `out/` (the build script never overwrites an existing ISO).

## Installation
1. Boot the ISO (UEFI or BIOS).
2. In the XFCE live session, open *Applications → Install System* (or run `calamares`).
3. Follow the Calamares wizard (locale, keyboard, partitioning, user creation).
4. Reboot into the installed system.

## Project layout
- `profile/` — archiso profile (see `profile/profiledef.sh`)
- `profile/airootfs/etc/calamares/` — Calamares configuration
- `packages/` — local `[echo]` repository and the Calamares PKGBUILD
- `scripts/` — build helpers
- `build.sh` — convenience wrapper around `mkarchiso`

## Notes
- Calamares uses the stock `default` branding component (no Echo OS–specific branding, colors, slideshow, or logo).
- The live user is removed from the installed target; the account you create during installation is the only user.
- The target's pacman package databases are refreshed during first boot / via post-install cleanup; with no network the databases remain empty but the installed system is already complete.
