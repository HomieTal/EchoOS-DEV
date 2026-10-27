# Echo OS component model

Echo OS is assembled from four independent components plus shared build
infrastructure. `build/assemble.sh` produces the ArchISO profile in
`build/generated/profile`; `build.sh` then builds and repacks the ISO.

## Components

| Component | Primary responsibility | Depends on |
| --- | --- | --- |
| `echo-core` | kernel, firmware, base system, initramfs, services, networking, live account, rescue tooling | — |
| `echo-boot` | rEFInd/EFI payloads, Syslinux, boot menus, live initramfs drop-in | `echo-core` |
| `echo-desktop` | KDE Plasma, SDDM, session/Wayland config, Echo look-and-feel, wallpapers, desktop apps | `echo-core` |
| `echo-install` | Calamares, installer modules/sequence, installer autostart and shortcut, live/target boundary | `echo-core`, `echo-boot` |
| `build/` | assembly, shared templates (`profiledef.sh`, `pacman.conf.in`), package merging, ISO repack, validation | — |

Declarative order lives in `build/config/components.tsv`; overlays live in
`build/config/overlays.tsv`.

## Ownership rules

1. A file has one primary owner. Cross-component use is expressed as a
   dependency, not by copying the file into two components.
2. A package is declared exactly once per architecture across all manifests.
   Assembly fails on duplicates.
3. Component overlays are additive; duplicate destination paths are an
   assembly error, even when contents are identical.
4. The Desktop component may depend on Core files (session, users, polkit) but
   must not replace Core system configuration. Likewise the Desktop does not
   own Calamares or the bootloader.
5. `profile/` is the historical reference profile (XFCE/LightDM era). It is
   never written by assembly; the build input is `build/generated/profile`.
6. The Calamares `unpackfs/exclude-list.txt` is the live/target boundary and is
   Installer-owned. Placing a file in a `live/` overlay does not exclude it from
   the target.

## Building

```bash
./build.sh
```

Steps: `build/assemble.sh` → `mkarchiso` (systemd-boot staging) →
`scripts/refind-iso.sh` (rEFInd ESP payload + ISO repack) → `out/*.iso`.
