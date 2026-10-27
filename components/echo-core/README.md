# echo-core

Owns the Echo OS **OS runtime**: kernel, base system, initramfs tooling,
firmware, filesystem/storage tools, networking, system services, the live
account, and live medium infrastructure. It is the base layer the other
components build on.

`echo-desktop` owns the graphical environment (KDE Plasma, SDDM, session
defaults); Core no longer declares XFCE or LightDM.

## Responsibilities

- Kernel and firmware: `linux`, `linux-firmware*`, `amd-ucode`, `intel-ucode`,
  `mkinitcpio`, `mkinitcpio-archiso`, `mkinitcpio-nfs-utils`.
- Base userland and system services: `base`, systemd units/sockets/timers,
  `polkit`, `sudo`, `openssh`, `cloud-init`, networking
  (`systemd-networkd`, `systemd-resolved`, `iwd`, `ModemManager`) and VM guest
  support.
- Filesystem, partitioning, encryption and rescue tooling (`cryptsetup`,
  `btrfs-progs`, `xfsprogs`, `lvm2`, `mdadm`, `dosfstools`, `squashfs-tools`,
  `arch-install-scripts`, ...).
- Live medium: the `archiso` live account, passwordless sudo/polkit for the
  live session, live-only systemd units, volatile journal, live MOTD, and
  `customize_airootfs.sh`.
- Live/target boundary inputs: Core supplies the live runtime, while the
  Installer's `unpackfs` exclude list decides what reaches the target.

## Not owned here

| Concern | Owner |
| --- | --- |
| Plasma, SDDM, session defaults, desktop apps, wallpapers/branding | `echo-desktop` |
| Calamares, installer policy, installer autostart/shortcut | `echo-install` |
| rEFInd, EFI payloads, boot menus | `echo-boot` |
| Profile assembly, package merging, ISO build | shared `build/` |

`polkit` stays in Core because it is a system service; the KDE polkit agent is
a desktop package (`polkit-kde-agent`) and therefore lives in `echo-desktop`.

## Layout

| Source prefix | Generated profile destination |
| --- | --- |
| `airootfs/` | `airootfs/` |
| `live/` | `airootfs/` |

`live/` means "live-oriented payload", not "automatically excluded from the
target". Exclusion remains the Installer's decision.

## Packages

Declared in `packages/packages.x86_64` and `packages/packages.aarch64`. Each
package is declared exactly once across all components; `build/assemble.sh`
fails on duplicates.

## Dependencies

- No component dependency; Core is the base layer.
- `echo-desktop` and `echo-install` depend on Core.
- `echo-boot` consumes Core's kernel, initramfs tooling and live root.
