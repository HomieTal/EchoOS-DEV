# echo-install

Status: **Step 3 — payload populated (not active).** Calamares configuration,
branding path, live polkit rule, PKGBUILD, and package manifests are migrated
from `profile/` with contents and permissions preserved. The installer workflow,
module sequence, unpackfs strategy, and target bootloader behavior remain
unchanged. `profile/` and Echo Boot remain authoritative/unchanged.

## Responsibilities

- Calamares module sequence and instances (`settings.conf`).
- Module configuration for partition/mount/fstab, locale/keyboard, users/sysusers/removeuser, machineid, initcpiocfg/initcpio, displaymanager, services-systemd, shellprocess (sysusers/cleanup), packages (no-op), bootloader, welcome/summary.
- Offline `unpackfs` from live SquashFS with `unpackfs/exclude-list.txt`.
- Target GRUB through Calamares (`modules/bootloader.conf`).
- Live-only polkit rule for launching Calamares.
- Live installer launch integration: one launch path through
  `usr/local/bin/echoos-install-launcher` (single-instance guard, bounded
  session wait, failure log at /tmp/echoos-install-launcher.log, escalation
  via `pkexec` only), wired as the "Install Echo OS" desktop shortcut
  (`config/home/archiso/Desktop/echoos-install.desktop`) and the XDG
  autostart entry (`config/live/etc/xdg/autostart/echoos-install.desktop`);
  all three are LIVE-EXCLUDED.
- Calamares package recipe and artifact.

## Migrated layout

| Component path | Source | Profile destination | Notes |
| --- | --- | --- | --- |
| `calamares/settings.conf` | `profile/airootfs/etc/calamares/settings.conf` | `airootfs/etc/calamares/settings.conf` | Module order preserved |
| `calamares/modules/*.conf` (16 files) | `profile/airootfs/etc/calamares/modules/*.conf` | `airootfs/etc/calamares/modules/*.conf` | Including unpackfs |
| `calamares/modules/unpackfs/exclude-list.txt` | `profile/airootfs/etc/calamares/modules/unpackfs/exclude-list.txt` | `airootfs/etc/calamares/modules/unpackfs/exclude-list.txt` | Live/target boundary |
| `config/live/polkit-1/rules.d/50-calamares.rules` | `profile/airootfs/etc/polkit-1/rules.d/50-calamares.rules` | `airootfs/etc/polkit-1/rules.d/50-calamares.rules` | LIVE-EXCLUDED |
| `config/live/etc/xdg/autostart/echoos-install.desktop` | - | `airootfs/etc/xdg/autostart/echoos-install.desktop` | XDG autostart; LIVE-EXCLUDED |
| `config/live/usr/local/bin/echoos-install-launcher` | - | `airootfs/usr/local/bin/echoos-install-launcher` | Launch path (0755); LIVE-EXCLUDED |
| `config/home/archiso/Desktop/echoos-install.desktop` | - | `airootfs/home/archiso/Desktop/echoos-install.desktop` | Desktop shortcut (0755); excluded via `/home/archiso` |
| `packages/PKGBUILD` | `packages/PKGBUILD` | - | Build input |
| `packages/calamares-3.4.2-2-x86_64.pkg.tar.zst` | `packages/calamares-3.4.2-2-x86_64.pkg.tar.zst` | - | Artifact (not source of truth) |
| `packages/packages.x86_64` | manifest | - | `[calamares]` |
| `packages/packages.aarch64` | manifest | - | `[]` (explicitly empty) |

`calamares/branding/` remains empty (stock branding). No branding changes.

## Overlays

From `build/config/overlays.tsv`: `calamares/` -> `airootfs/etc/calamares/`, `config/live/` -> `airootfs/etc/`, `config/home/` -> `airootfs/home/`.

## Dependencies

- **Echo Core**: live root, base, desktop, users, filesystem utilities.
- **Echo Boot**: target bootloader packages/policy. `modules/bootloader.conf` remains Installer-owned.
- **Shared**: local repo, templates.

## Boundaries

- Live boot: systemd-boot (UEFI), Syslinux (BIOS) — owned by Echo Boot.
- Installed bootloader: GRUB via Calamares — owned by Echo Install; rEFInd not integrated.
- Unpackfs not replaced; no installer redesign.
- Current exclude list behavior preserved (Calamares may leak to target by current policy; recorded).

## Assembly

No generation in Step 3. `build/assemble.sh` remains blocked until Echo Core and shared templates are present.

## Validation

`./build/validate.sh` will be updated to verify Installer payloads, manifests, source parity, permissions/links, and mappings. Profile parity is **not established**.
