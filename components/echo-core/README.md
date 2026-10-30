# echo-core

Status: **Active.** Echo Core is a real assembly component. Its payloads are
merged into `build/generated/profile` by `build/assemble.sh`, and it is the base
layer that every other component may depend on.

Echo Core owns the non-graphical system: kernel, firmware, initramfs tooling,
filesystem and networking utilities, base services, hardware support, the live
account, and live infrastructure. The graphical session belongs to
`echo-desktop`; boot menus belong to `echo-boot`; the installer belongs to
`echo-install`.

## Responsibilities

- Base system packages: kernel, firmware, microcode, initramfs tooling,
  filesystem tools, networking, rescue utilities, and virtualization guest
  support.
- systemd services, sockets, timers, network configuration, and target service
  defaults.
- Live account, live sudo/polkit policy, getty autologin, live helper scripts,
  live MOTD, volatile journal, and power/logind policy.
- Live/target boundary inputs that are not installer policy: the live account,
  live SSH policy, mirror/pacman-init/livecd units, and live shell files.
- Package declarations for all Core-owned packages.
- The `customize_airootfs.sh` hook that creates the live user, groups, and live
  home during ISO build.

Core does **not** own XFCE, LightDM, KDE Plasma, SDDM, Calamares, boot menus,
or rEFInd. Those moved to their components.

## Layout

```text
airootfs/                       common payload (live and installed target)
live/                           live-oriented payload (overlaid at airootfs/)
packages/packages.x86_64        Core package manifest
packages/packages.aarch64       Core package manifest
services/                       reserved (currently empty)
```

Overlay mapping from `build/config/overlays.tsv`:

| Source prefix | Generated profile destination |
| --- | --- |
| `airootfs/` | `airootfs/` |
| `live/` | `airootfs/` |

`live/` means "live-oriented payload", not "automatically excluded from the
target". Exclusion remains Installer-owned policy in
`components/echo-install/calamares/modules/unpackfs/exclude-list.txt`.

## Common versus live payload

Common files delivered to both the live root and the installed target include:

- `etc/hostname`, `etc/locale.conf`
- `etc/systemd/network/20-{ethernet,wlan,wwan}.network`
- `etc/systemd/networkd.conf.d/ipv6-privacy-extensions.conf`
- `etc/systemd/system/systemd-networkd-wait-online.service.d/`

Live-oriented files under `live/` include:

- `etc/passwd`, `etc/shadow`, `etc/sysusers.d/99-live-user.conf`
- `etc/sudoers.d/archiso`, `etc/security/faillock.conf`
- `etc/ssh/sshd_config.d/10-archiso.conf`
- `etc/motd`, volatile journal, logind and resolved drop-ins
- `choose-mirror`, `pacman-init`, `livecd-*` units and helpers
- `getty@tty1.service.d/autologin.conf`
- `root/customize_airootfs.sh`, `root/.zlogin`, `root/.gnupg/scdaemon.conf`

The current Calamares exclude list remains the authoritative live/target
boundary. Do not move a file between `airootfs/` and `live/` to change whether
it reaches the target; change the exclude list deliberately.

## Packages

`packages/packages.x86_64` and `packages/packages.aarch64` list Core-owned
packages: `base`, `linux`, `linux-firmware*`, `linux-dtbs`, microcode,
`mkinitcpio`, `mkinitcpio-nfs-utils`, filesystem and storage tools
(`btrfs-progs`, `e2fsprogs`, `xfsprogs`, `exfatprogs`, `f2fs-tools`,
`jfsutils`, `nilfs-utils`, `ntfsprogs`, `bcachefs-tools`, `lvm2`, `mdadm`,
`dmraid`, `cryptsetup`, `dosfstools`, `fatresize`, `mtools`, `squashfs-tools`),
networking and remote access tools, virtualization guest packages, `cloud-init`,
`livecd-sounds`, and `mkinitcpio-archiso`.

`arch-install-scripts` is Core live/rescue tooling. `python` is Core general
tooling. `dosfstools` and `fatresize` stay in Core even though Calamares may
invoke them. The desktop stack is declared only by `echo-desktop`.

## Dependencies

- No component dependency. Core is the base layer.
- `echo-boot`, `echo-desktop`, and `echo-install` may depend on Core.
- Core must not declare desktop packages or installer configuration.

## Shared build infrastructure

- `build/template/profiledef.sh` owns `file_permissions`, ISO metadata, and boot
  mode selection.
- `build/config/pacman.conf.in` and the generated package lists are shared.
- `build/assemble.sh` merges overlays and package manifests in component order.

## Validation

`./build/validate.sh` assembles both architectures into temporary directories,
checks component order and dependencies, rejects duplicate or conflicting
packages, and verifies the assembled live/target boundary. It does not build or
boot an ISO.

## Out of scope

- XFCE, LightDM, KDE Plasma, SDDM, and desktop branding.
- Calamares, installer launchers, and target bootloader policy.
- rEFInd boot menus and EFI assets.
