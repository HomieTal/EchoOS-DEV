# echo-install

Calamares and everything specific to installing Echo OS. The desktop supplies
the running Plasma session; the installer never owns desktop configuration.

## Responsibilities

- Calamares module sequence and instances (`settings.conf`).
- Module configuration for partition/mount/fstab, locale/keyboard,
  users/sysusers/removeuser, machineid, initcpiocfg/initcpio, **SDDM**
  displaymanager, services-systemd, shellprocess (sysusers/cleanup/refindboot),
  packages (no-op), welcome/summary.
- Offline `unpackfs` from live SquashFS with `unpackfs/exclude-list.txt`.
- Target bootloader: rEFInd installed with
  `shellprocess-refindboot.conf` (`refind-install --alldrivers --yes`) after
  mounting the ESP at `/boot` (`partition.conf`).
- Live-only polkit rule for launching Calamares.
- Live installer launch integration: one launch path through
  `usr/local/bin/echoos-install-launcher` (single-instance guard, bounded
  session wait, failure log at /tmp/echoos-install-launcher.log, escalation
  via `pkexec` only), wired as the "Install Echo OS" desktop shortcut
  (`config/home/archiso/Desktop/echoos-install.desktop`) and the XDG
  autostart entry (`config/live/etc/xdg/autostart/echoos-install.desktop`).
  The launcher forwards `DISPLAY`, `XAUTHORITY` and `XDG_RUNTIME_DIR` through
  `pkexec /usr/bin/env`, because pkexec sanitises the environment and
  Calamares otherwise aborts with "could not connect to display".
- `usr/local/bin/echoos-calamares`: installer-owned wrapper that pins
  `QT_QPA_PLATFORM=xcb` so Calamares runs in XWayland inside the Plasma
  Wayland live session (Plasma 6.8 ships no X11 session).
- Calamares package recipe and artifact.

## Migrated layout

| Component path | Source | Profile destination | Notes |
| --- | --- | --- | --- |
| `calamares/settings.conf` | `profile/airootfs/etc/calamares/settings.conf` | `airootfs/etc/calamares/settings.conf` | Module order preserved |
| `calamares/modules/*.conf` (16 files) | `profile/airootfs/etc/calamares/modules/*.conf` | `airootfs/etc/calamares/modules/*.conf` | Including unpackfs |
| `calamares/modules/unpackfs/exclude-list.txt` | `profile/airootfs/etc/calamares/modules/unpackfs/exclude-list.txt` | `airootfs/etc/calamares/modules/unpackfs/exclude-list.txt` | Live/target boundary |
| `config/live/polkit-1/rules.d/50-calamares.rules` | `profile/airootfs/etc/polkit-1/rules.d/50-calamares.rules` | `airootfs/etc/polkit-1/rules.d/50-calamares.rules` | LIVE-EXCLUDED |
| `config/live/etc/xdg/autostart/echoos-install.desktop` | - | `airootfs/etc/xdg/autostart/echoos-install.desktop` | XDG autostart; LIVE-EXCLUDED |
| `config/rootfs/usr/local/bin/echoos-install-launcher` | - | `airootfs/usr/local/bin/echoos-install-launcher` | Launch path (0755); LIVE-EXCLUDED |
| `config/rootfs/usr/local/bin/echoos-calamares` | - | `airootfs/usr/local/bin/echoos-calamares` | XWayland wrapper for Calamares (0755); LIVE-EXCLUDED |
| `config/home/archiso/Desktop/echoos-install.desktop` | - | `airootfs/home/archiso/Desktop/echoos-install.desktop` | Desktop shortcut (0755); excluded via `/home/archiso` |
| `packages/PKGBUILD` | `packages/PKGBUILD` | - | Build input |
| `packages/calamares-3.4.2-2-x86_64.pkg.tar.zst` | `packages/calamares-3.4.2-2-x86_64.pkg.tar.zst` | - | Artifact (not source of truth) |
| `packages/packages.x86_64` | manifest | - | `[calamares]` |
| `packages/packages.aarch64` | manifest | - | `[]` (explicitly empty) |

`calamares/branding/` remains empty (stock branding). No branding changes.

## Overlays

From `build/config/overlays.tsv`: `calamares/` -> `airootfs/etc/calamares/`, `config/live/` -> `airootfs/etc/`, `config/home/` -> `airootfs/home/`.

## Dependencies

- **Echo Core**: live root, base, network, users, filesystem utilities.
- **Echo Desktop**: provides the graphical session and SDDM; the installer's
  `displaymanager.conf` targets SDDM but does not own its configuration.
- **Echo Boot**: rEFInd package and EFI assets. The install-time rEFInd
  invocation (`shellprocess-refindboot.conf`) is Installer-owned policy.
- **Shared**: local repo, templates.

## Boundaries

- Live boot: rEFInd (UEFI), Syslinux (BIOS) — owned by Echo Boot.
- Installed bootloader: rEFInd (UEFI) or GRUB (BIOS), invoked by this
  component's `shellprocess-refindboot.conf`.
- Live/target boundary: `/etc/sddm.conf.d/` (live autologin), the live
  installer launcher/wrapper, Calamares polkit rule, live home and live
  units are excluded from the target. `/etc/sddm.conf` remains in the target
  but carries no `[Autologin]` section, so it cannot mask the live drop-in;
  Calamares' displaymanager module writes the target autologin there.

## Assembly

`build/assemble.sh` overlays this component after Core/Boot/Desktop; duplicate
destination paths are hard failures. Calamares' configuration now matches the
shipped rEFInd installer (`partition.conf`, `shellprocess-refindboot.conf`,
`settings.conf`), removing the drift that would otherwise have reinstalled
GRUB.

## Validation

- `build/assemble.sh` (destination/package duplicate checks).
- Static verification of `settings.conf` module order, SDDM module config,
  exclude list, launcher/wrapper permissions, and pkexec environment
  forwarding.
- Live boot and installer launcher behaviour are boot-tested in a UEFI VM;
  see the Step 8 report. Full install-to-disk is reported honestly there.
