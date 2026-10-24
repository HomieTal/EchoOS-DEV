# echo-core

Status: **Step 1 skeleton only.** This directory has no payload yet. The active
core configuration remains under `profile/airootfs/`.

## Responsibilities

- Base system packages: kernel, firmware, initramfs tooling, filesystem tools,
  networking, rescue utilities, and virtualization guest support.
- XFCE desktop, LightDM, accountsservice, polkit, icons, themes, and session
  tooling.
- systemd services, sockets, timers, network configuration, and target service
  defaults that currently survive installation.
- Live account, live sudo/polkit policy, autologin, live helper scripts, live
  MOTD, volatile journal, and power/logind policy.
- Package declarations for all Core-owned packages.
- Preserving the existing live/target boundary. It is not this component's job
  to "fix" current live-only leakage in Step 1.

## Existing files expected to belong here

The complete mapping is in `build/config/legacy-file-owners.tsv`. This component
owns 66 profile files:

- **33 `COMMON` files** delivered to both the live root and the installed
  target, including network configuration, cloud-init wants, ModemManager/iwd/
  sshd/hypervisor/virtualbox/vmware service links, LightDM configuration,
  hostname, locale, resolv.conf, and systemd timesync/socket units.
- **18 `LIVE-EXCLUDED` files** currently excluded by the Calamares exclude
  list: live autologin, live passwordless sudo, live SSH policy, pacman build
  hooks, live mirror/pacman-init/livecd units and wants, getty autologin,
  display-manager link, and faillock policy.
- **15 `LIVE-INTENDED` files** that are live-oriented but currently **not**
  excluded from the target: live passwd/shadow, sysusers, live helper scripts
  and assets, live MOTD, volatile journal, logind policy, resolved policy,
  pacman gnupg mount, gpt-auto-generator override, root `.zlogin`, root
  `.gnupg/scdaemon.conf`, and the live account fixup script.

`LIVE-INTENDED` records the current behavior. Moving a file into a `live/`
overlay later must not silently remove it from the target; the existing 25-line
exclude list remains the parity reference until a separate boundary change is
reviewed.

The two empty profile directories are also Core-owned:

- `profile/airootfs/home/archiso/` (live user home; currently excluded)

and the installer-owned empty branding directory is not part of Core.

Proposed future locations use these overlay prefixes:

| Source prefix | Generated profile destination |
| --- | --- |
| `airootfs/` | `airootfs/` |
| `live/` | `airootfs/` |

The `live/` location means "live-oriented payload", not "automatically excluded
from the target". Exclusion is a separate installer-owned policy.

## Existing packages expected to belong here

150 of the 159 unique package declarations are Core-owned. The complete list is
in `build/config/legacy-package-owners.tsv`; notable groups include:

- `base`, `linux`, `linux-firmware*`, `linux-dtbs`, microcode, `mkinitcpio`,
  `mkinitcpio-nfs-utils`
- `lightdm`, `lightdm-gtk-greeter`, `accountsservice`, `polkit`,
  `polkit-gnome`, XFCE, icon, and terminal packages
- filesystem and storage tools: `btrfs-progs`, `e2fsprogs`, `xfsprogs`,
  `exfatprogs`, `f2fs-tools`, `jfsutils`, `nilfs-utils`, `ntfsprogs`,
  `bcachefs-tools`, `lvm2`, `mdadm`, `dmraid`, `cryptsetup`, `dosfstools`,
  `fatresize`, `mtools`, `squashfs-tools`
- networking, remote access, and live rescue tools
- virtualization guest packages and `cloud-init`
- `livecd-sounds` and `mkinitcpio-archiso` (live-oriented; current file-level exclusions do not remove their package payloads from the target)

`arch-install-scripts` is Core live/rescue tooling, not a Calamares dependency.
`python` is Core general tooling and is not assigned to Installer solely because
Calamares can use Python modules. `dosfstools` and `fatresize` stay in Core even
though Calamares may invoke them.

## Dependencies

- No component dependency. Core is the base layer.
- `echo-boot` consumes the kernel, firmware, initramfs tooling, and live root.
- `echo-install` consumes Core runtime, desktop, user, filesystem, and live
  helper content.
- Shared build infrastructure supplies package-list generation,
  `profiledef.sh` `file_permissions` (including live account paths), pacman
  configuration, and the local repository.

## Shared build infrastructure

- `profile/profiledef.sh` owns `file_permissions` for `/etc/shadow`,
  `/etc/gshadow`, `/root`, `/etc/passwd`, `/etc/group`, live sudoers, live
  polkit, live sysusers, LightDM, and `/home/archiso`. It remains a single
  shared template; Core does not duplicate it.
- `profile/pacman.conf.in` and the generated package lists remain shared.
- The Calamares exclude list is Installer-owned, even though it names Core
  paths.

## Package manifest format (proposed)

When payloads are introduced, this component will provide:

```text
components/echo-core/packages/packages.x86_64
components/echo-core/packages/packages.aarch64
```

The format is one package name per line, blank lines and `#` comments ignored.
Both architecture files are required. The union across components must exactly
equal the current legacy set for that architecture. See
`docs/step-1-assembly-contract.md`.

## Intentionally out of scope for Step 1

- Copying any Core file into this directory.
- Changing XFCE, LightDM, services, users, networking, or package selections.
- Removing live-only leakage or editing the Calamares exclude list.
- KDE, Echo branding, animal codenames, or Aira.
- Building an ISO or booting/installing it.
