# Echo OS - Phase 1 Architecture Report and Migration Plan

**Status:** Phase 1 only. No existing repository file was modified.
**Date:** 2026-10-24
**Repository under inspection:** `/home/ghost/Desktop/EchoOS-DEV`
**Original repository:** `/home/ghost/Projects/echo-os` (left untouched)
**Method:** static inspection of the Git work tree, the built ISO, the installed ArchISO/Calamares tooling, and the upstream `releng` profile. No ISO build, boot, or installation test was executed for this report. No partitioning operation was performed.

> The repository was copied to the Desktop at the user's request. The original at `/home/ghost/Projects/echo-os` and its build artifacts were not changed. The copy excludes the regenerable `out/` and `work/` directories.

---

## 1. Executive summary

The current project is a working ArchISO `releng` derivative, not yet an Echo OS distribution build:

- The live medium is **XFCE + LightDM**, not KDE Plasma.
- The live boot manager is **systemd-boot on UEFI** and **syslinux on BIOS**. **rEFInd is installed as a package but is not part of the live boot path.**
- Calamares installs the target by unpacking the live squashfs (`unpackfs`), then installs **GRUB** as the target bootloader. There is no separate installed-system package model.
- Calamares uses its stock **`default`** branding. There is no Echo OS Calamares branding, logo, slideshow, or product name.
- ISO identity is still Arch Linux (`iso_name="archlinux"`, `ARCH_...` label, Arch publisher), and every boot-menu title says "Arch Linux install medium".
- There is no `os-release`, release manifest, version file, automated test, validation script, CI, or Aira integration point.
- The three-component split is feasible and does not require forking ArchISO. However, four constraints drive the design:
  1. **ArchISO 91 has no rEFInd live boot mode.** Its only boot-mode implementations are `bios.syslinux`, `uefi.systemd-boot`, and the `uefi.grub` family. A live rEFInd boot cannot be produced by changing `bootmodes` or a filename.
  2. **The installed system is a copy of the live root.** Live-only and target-only content must therefore be modeled explicitly, or the installed system will keep live-only packages and configuration.
  3. **Calamares 3.4.2 does support `efiBootLoader: "refind"`,** so rEFInd is technically valid for the *installed* UEFI system. The current configuration uses GRUB and has no `refindKernelList`.
  4. **The local repository has diverged from GitHub and has significant uncommitted work.** The local `main` has no configured remote; GitHub `main` is a different flat-layout history from 2026-08-06.

The recommended migration is therefore a behavior-preserving refactor: keep the current live boot chain and installer behavior, split ownership into Boot/Install/Core, generate the final ArchISO profile from those components, and validate parity before changing the desktop, branding, or bootloader. KDE, Echo branding, rEFInd-on-target, and Aira should be separate follow-up changes.

---

## 2. Repository and build snapshot

### 2.1 Git state

| Item | Observed value |
|---|---|
| Local branch | `main` |
| Local HEAD | `e6d1fa5` - `feat: integrate Calamares with live XFCE session` (2026-10-21 21:25 +0530) |
| Local history | 3 commits, starting with an ArchISO `releng` import |
| Configured remote | **none** (`git remote -v` is empty) |
| Working tree | **dirty**: 7 modified tracked files, 2 untracked files |
| GitHub `HomieTal/EchoOS-DEV` `main` | `30bcd14` - `Merge remote main into local project` (2026-08-06) |
| GitHub layout | flat (`profiledef.sh`, `airootfs/`, `packages.x86_64`, ...) |
| Local layout | `profile/` subdirectory plus Calamares and a local package repository |
| Relationship | The local tree is **not** a descendant of the current GitHub `main`. It is a separate development line. |

Dirty/untracked files that must be preserved before any migration:

- Modified: `profile/airootfs/etc/calamares/modules/unpackfs/exclude-list.txt`
- Modified: `profile/airootfs/etc/polkit-1/rules.d/50-calamares.rules`
- Modified: `profile/airootfs/etc/shadow`
- Modified: `profile/airootfs/etc/systemd/system/display-manager.service`
- Modified: `profile/packages.aarch64`
- Modified: `profile/packages.x86_64`
- Modified: `profile/profiledef.sh`
- Untracked: `profile/airootfs/etc/security/faillock.conf`
- Untracked: `profile/airootfs/root/customize_airootfs.sh`

These changes contain the live-session login fix (shadow entry, faillock policy, `accountsservice`, deterministic display-manager symlink). They must be committed on a branch before files are moved.

### 2.2 Toolchain observed on the build host

| Tool | Version / state |
|---|---|
| Host OS | Arch Linux (rolling) |
| `archiso` | `91-1` |
| `calamares` | `3.4.2-2` |
| `systemd` | `262.1-1` |
| `pacman` | `7.1.0` / libalpm `16.0.1` |
| `mkarchiso` | `/usr/bin/mkarchiso`, no validate-only mode |
| Host `refind`, `grub`, `syslinux` | **not installed on the host** (they are installed only inside the ISO) |
| `shellcheck`, `yamllint`, PyYAML | **not installed** |
| QEMU, libvirt, OVMF | **not found** in `PATH` / standard paths |
| `pacman-conf` | available and successfully parsed the current `profile/pacman.conf` |

The missing VM tooling is a Phase 7 blocker, not a Phase 1 blocker.

### 2.3 Existing build outputs

| Path | Observed |
|---|---|
| `out/archlinux-2026.10.21-x86_64.iso` | 1.8 GiB, built 2026-10-21 23:21 |
| `out/` and `work/` | gitignored; excluded from the Desktop copy by design |
| `work/iso/arch/pkglist.x86_64.txt` | 589 packages |
| ISO volume label | `ARCH_202610` |
| ISO publisher | `ARCH LINUX <HTTPS://ARCHLINUX.ORG>` |
| ISO application | `ARCH LINUX LIVE/RESCUE DVD` |
| ISO boot modes | BIOS El Torito (`isolinux.bin`) + UEFI El Torito (`efiboot.img`, systemd-boot) |

**The existing ISO is stale.** Seven source files are newer than the ISO, including the entire live-login fix:

- `profile/airootfs/etc/shadow`
- `profile/airootfs/root/customize_airootfs.sh` (created after the ISO build)
- `profile/airootfs/etc/security/faillock.conf`
- `profile/airootfs/etc/calamares/modules/unpackfs/exclude-list.txt`
- `profile/airootfs/etc/polkit-1/rules.d/50-calamares.rules`
- `profile/packages.x86_64`
- `profile/packages.aarch64`

For example, `accountsservice` is in the working-tree package list but **not** in the built ISO. The existing ISO must not be treated as validation of the current working tree.

---

## 3. Current build and runtime architecture

### 3.1 Build pipeline (as implemented)

```text
scripts/render-pacman-conf.sh
        |
        v
profile/pacman.conf  (rewritten in place; absolute [echo] repo path)
        |
        v
./build.sh  ->  sudo mkarchiso -v -w work -o out -C profile/pacman.conf profile
        |
        v
out/archlinux-YYYY.MM.DD-x86_64.iso
```

`build.sh` renders `profile/pacman.conf` from `profile/pacman.conf.in` on every run, then calls `mkarchiso` with the source profile directly. There is no assembly step, no validation step, and no separation between generated and source files.

### 3.2 Live boot chain (observed in the built ISO)

```text
BIOS:  El Torito -> /boot/syslinux/isolinux.bin -> syslinux.cfg -> archiso_sys.cfg
       -> LINUX /arch/boot/x86_64/vmlinuz-linux
       -> INITRD /arch/boot/x86_64/initramfs-linux.img
       -> APPEND archisobasedir=arch archisosearchuuid=... %KERNEL_PARAMS%

UEFI:  El Torito -> efiboot.img (FAT) -> /EFI/BOOT/BOOTx64.EFI (systemd-boot)
       -> /loader/loader.conf -> /loader/entries/01-archiso-linux.conf
       -> /arch/boot/x86_64/vmlinuz-linux + initramfs-linux.img
       -> options archisobasedir=arch archisosearchuuid=... %KERNEL_PARAMS%
```

Facts:

- `profiledef.sh` declares `bootmodes=('bios.syslinux' 'uefi.systemd-boot')`.
- `profile/efiboot/loader/entries/` contains the normal, speech, and Memtest86+ entries.
- `profile/syslinux/` contains the BIOS menu, PXE menu, splash, and accessibility entry.
- `profile/grub/grub.cfg` exists but is **not used** by the current boot modes. `mkarchiso` still installs `/boot/grub/loopback.cfg` because `bootmodes` does not contain `grub`.
- The ISO contains `EFI/BOOT/BOOTx64.EFI`, `EFI/BOOT/BOOTIA32.EFI`, `efiboot.img`, and `loader/`; it does **not** contain `EFI/refind/` or a rEFInd binary.
- `refind 0.14.2-3` is present in the live package list, but only as an unused package. It is not configured and is not part of the ISO boot path.
- No Echo OS branding appears in any boot menu, splash, or ISO identity field.

### 3.3 Installer chain (Calamares 3.4.2)

`settings.conf` sequence:

```text
show: welcome, locale, keyboard, partition, users, summary
exec: partition, mount, unpackfs, shellprocess@sysusers, removeuser,
      machineid, locale, keyboard, localecfg, fstab, initcpiocfg, initcpio,
      users, displaymanager, hwclock, services-systemd, packages,
      bootloader, shellprocess@cleanup, umount
show: finished
```

Key behavior:

- `unpackfs` copies the live squashfs to the target and copies `/run/archiso/bootmnt/arch/boot/x86_64` to `/boot`. It is an **offline copy install**, not a package-based install.
- `packages.conf` has `operations: []`; it is a no-op.
- `shellprocess-sysusers` runs `systemd-sysusers` in the target before `users`.
- `removeuser` removes the live `archiso` user.
- `shellprocess-cleanup` removes `calamares`, `mkinitcpio-archiso`, and `livecd-sounds`; replaces `/etc/motd`; attempts `pacman -Sy`.
- `bootloader.conf` uses `efiBootLoader: "grub"` and GRUB commands. It does not use rEFInd and has no `refindKernelList`.
- `displaymanager.conf` enables LightDM; `services-systemd.conf` enables `systemd-networkd`, `systemd-resolved`, and `lightdm`.
- Calamares branding is `default` (stock), and `profile/airootfs/etc/calamares/branding/` is empty.
- The live-only file boundary is maintained by hand in `unpackfs/exclude-list.txt`. It excludes the live user, sudoers file, autologin, live services, polkit rule, faillock policy, and the live display-manager link.
- `/etc/calamares/` itself is **not** in the exclude list. Because those files come from `airootfs`, not from the Calamares package, uninstalling Calamares in the cleanup step does not remove them. This is a target-cleanliness leak.

### 3.4 Package and repository chain

- Build-time repositories: official `core` and `extra` only; local `[echo]` is added at the end.
- Local `[echo]` repository: `Server = file:///home/ghost/Projects/echo-os/packages`, `SigLevel = Optional TrustAll`.
- Local repository contents: `calamares-3.4.2-2-x86_64.pkg.tar.zst`, `echo.db.tar.zst`, `echo.files.tar.zst`, and the source `PKGBUILD`.
- `packages/echo.db` and `packages/echo.files` are tracked symlinks; the actual `.tar.zst` files and the Calamares package are gitignored. A fresh clone therefore has repository metadata symlinks but no package payload.
- `profile/pacman.conf` is generated from `profile/pacman.conf.in` but is also tracked. It contains a machine-specific absolute path, so it is currently wrong for the Desktop copy until rendered.
- `profile/packages.x86_64` has 156 lines and no duplicates; `profile/packages.aarch64` has 145 lines and no duplicates. Both are flat package-name lists with no comments or whitespace errors.

### 3.5 Desktop / services state

- Live and installed desktop: **XFCE**, session `xfce`, display manager **LightDM** with `lightdm-gtk-greeter`.
- No KDE Plasma, SDDM, KWin, NetworkManager, PipeWire, or Plasma service configuration exists.
- The live session uses `archiso` (uid 1000), autologin, passwordless sudo, a live shadow entry, and live-only polkit/faillock policy.
- Target services enabled by Calamares: `systemd-networkd`, `systemd-resolved`, `lightdm`.
- The installed target inherits many live rescue/desktop packages because only three packages are removed during cleanup.

### 3.6 Identity and branding state

| Item | Current value |
|---|---|
| `iso_name` | `archlinux` |
| `iso_label` | `ARCH_$(date +%Y%m)` |
| `iso_publisher` | `Arch Linux <https://archlinux.org>` |
| `iso_application` | `Arch Linux Live/Rescue DVD` |
| Live hostname | `archiso` |
| Live MOTD | Generic live-environment instructions |
| Calamares branding | `default` (stock) |
| Boot titles | "Arch Linux install medium (...)" |
| Echo OS visual identity | none found |
| `os-release` override | none |
| Release version file | none |
| Aira references | none |

---

## 4. Complete current-file responsibility map

Legend:

- **BOOT** - live ISO boot infrastructure or installed-system boot policy.
- **INSTALL** - Calamares, its live launcher policy, or the installer package.
- **CORE** - operating-system content used by both live and installed systems.
- **CORE-LIVE** - operating-system content that is live-only and must be excluded from the target.
- **SHARED** - build infrastructure, repository metadata, release identity, or documentation.
- **GENERATED** - should become an output of assembly, not a hand-maintained source file.

### 4.1 Boot component

| Path | Responsibility |
|---|---|
| `profile/efiboot/loader/loader.conf` | systemd-boot timeout/default/beep |
| `profile/efiboot/loader/entries/01-archiso-linux.conf` | Normal UEFI live entry |
| `profile/efiboot/loader/entries/02-archiso-speech-linux.conf` | UEFI accessibility entry |
| `profile/efiboot/loader/entries/03-archiso-memtest86+x64.conf` | UEFI Memtest86+ entry |
| `profile/syslinux/syslinux.cfg` | BIOS/PXE menu selector |
| `profile/syslinux/archiso_sys.cfg` | BIOS local-boot menu |
| `profile/syslinux/archiso_sys-linux.cfg` | BIOS normal and speech entries |
| `profile/syslinux/archiso_pxe.cfg` | PXE menu |
| `profile/syslinux/archiso_pxe-linux.cfg` | PXE NBD/NFS/HTTP entries |
| `profile/syslinux/archiso_head.cfg` | BIOS menu theme and layout |
| `profile/syslinux/archiso_tail.cfg` | BIOS existing-OS/Memtest/HDT/reboot/poweroff entries |
| `profile/syslinux/splash.png` | BIOS boot splash artwork |
| `profile/grub/grub.cfg` | GRUB live menu (currently inactive because GRUB is not a boot mode) |
| `profile/grub/loopback.cfg` | ISO loopback boot menu (installed into `/boot/grub/` by ArchISO) |
| `profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf` | Live initramfs hooks and compression |
| `profile/profiledef.sh` - `bootmodes`, `kernel_params_*` | Boot-mode declarations and kernel command line |
| `profile/profiledef.sh` - boot-related `file_permissions` | Permissions for boot/runtime files |
| `profile/packages.x86_64` - boot entries | `syslinux`, `edk2-shell`, `memtest86+`, `memtest86+-efi`, `refind`, `grub` |
| `profile/packages.aarch64` - boot entries | `grub`, `edk2-shell`, `stubble` |

Note: the kernel, firmware, microcode, and `mkinitcpio` are operating-system packages (CORE). Boot should declare them as requirements rather than duplicate them.

### 4.2 Installer component

| Path | Responsibility |
|---|---|
| `profile/airootfs/etc/calamares/settings.conf` | Module sequence, instances, branding selector, global behavior |
| `profile/airootfs/etc/calamares/modules/welcome.conf` | Installer requirements screen |
| `profile/airootfs/etc/calamares/modules/locale.conf` | Locale/timezone selection |
| `profile/airootfs/etc/calamares/modules/machineid.conf` | Target machine-id generation |
| `profile/airootfs/etc/calamares/modules/mount.conf` | Target mounts, btrfs subvolumes, mount options |
| `profile/airootfs/etc/calamares/modules/unpackfs.conf` | Offline copy of live squashfs and `/boot` |
| `profile/airootfs/etc/calamares/modules/unpackfs/exclude-list.txt` | Hand-maintained live/target file boundary |
| `profile/airootfs/etc/calamares/modules/fstab.conf` | Target `/etc/fstab` generation |
| `profile/airootfs/etc/calamares/modules/initcpiocfg.conf` | Target initramfs hook configuration |
| `profile/airootfs/etc/calamares/modules/initcpio.conf` | Target initramfs generation |
| `profile/airootfs/etc/calamares/modules/users.conf` | Target user, groups, sudo, root password, hostname |
| `profile/airootfs/etc/calamares/modules/removeuser.conf` | Removal of the live user |
| `profile/airootfs/etc/calamares/modules/displaymanager.conf` | Target display manager (LightDM) |
| `profile/airootfs/etc/calamares/modules/services-systemd.conf` | Target enabled services |
| `profile/airootfs/etc/calamares/modules/packages.conf` | No-op package module |
| `profile/airootfs/etc/calamares/modules/bootloader.conf` | Target bootloader policy (currently GRUB) |
| `profile/airootfs/etc/calamares/modules/shellprocess-sysusers.conf` | Target user/group database bootstrap |
| `profile/airootfs/etc/calamares/modules/shellprocess-cleanup.conf` | Target cleanup and package removal |
| `profile/airootfs/etc/calamares/branding/` | Empty directory; stock `default` branding is used |
| `profile/airootfs/etc/polkit-1/rules.d/50-calamares.rules` | Live-only passwordless Calamares launch |
| `packages/PKGBUILD` | Calamares 3.4.2 source build recipe |
| `packages/calamares-3.4.2-2-x86_64.pkg.tar.zst` | Built Calamares package (gitignored artifact) |
| `profile/packages.x86_64` - `calamares` | Installer package selection |

Cross-component coupling to remove: `displaymanager.conf` and `services-systemd.conf` hardcode LightDM and its services. They must be generated from Core's desktop/service declaration, otherwise switching Core to KDE Plasma requires editing Echo Install.

### 4.3 Core component

Common operating-system content (live and target):

| Path | Responsibility |
|---|---|
| `profile/airootfs/etc/hostname` | Live hostname (`archiso`); target hostname is rewritten by Calamares |
| `profile/airootfs/etc/locale.conf` | Live locale |
| `profile/airootfs/etc/localtime` | UTC timezone symlink |
| `profile/airootfs/etc/resolv.conf` | systemd-resolved stub symlink |
| `profile/airootfs/etc/systemd/network/20-ethernet.network` | Ethernet DHCP/route metric |
| `profile/airootfs/etc/systemd/network/20-wlan.network` | Wi-Fi DHCP/route metric |
| `profile/airootfs/etc/systemd/network/20-wwan.network` | WWAN DHCP/route metric |
| `profile/airootfs/etc/systemd/networkd.conf.d/ipv6-privacy-extensions.conf` | IPv6 privacy defaults |
| `profile/airootfs/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service` | ModemManager D-Bus alias |
| `profile/airootfs/etc/systemd/system/dbus-org.freedesktop.network1.service` | networkd D-Bus alias |
| `profile/airootfs/etc/systemd/system/dbus-org.freedesktop.resolve1.service` | resolved D-Bus alias |
| `profile/airootfs/etc/systemd/system/dbus-org.freedesktop.timesync1.service` | timesyncd D-Bus alias |
| `profile/airootfs/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service` | Network-online dependency |
| `profile/airootfs/etc/systemd/system/sockets.target.wants/pcscd.socket` | Smart-card socket |
| `profile/airootfs/etc/systemd/system/sockets.target.wants/systemd-networkd.socket` | networkd socket |
| `profile/airootfs/etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service` | Time synchronization |
| `profile/airootfs/etc/systemd/system/sysinit.target.wants/systemd-time-wait-sync.service` | Time synchronization |
| `profile/airootfs/etc/systemd/system/systemd-networkd-wait-online.service.d/wait-for-only-one-interface.conf` | Network wait tuning |
| `profile/airootfs/etc/lightdm/lightdm.conf` | Display-manager configuration (currently LightDM) |
| `profile/packages.x86_64` / `packages.aarch64` - base/desktop | Kernel, firmware, microcode, XFCE, Xorg, fonts, utilities |
| `profile/bootstrap_packages` | ArchISO bootstrap package set |

Currently excluded from the target (verified against `unpackfs/exclude-list.txt`):

| Path | Reason |
|---|---|
| `/etc/mkinitcpio.conf.d/archiso.conf` | Live initramfs configuration |
| `/etc/pacman.d/hooks/` | Build-time pacman hooks |
| `/etc/ssh/sshd_config.d/10-archiso.conf` | Live root/password SSH policy |
| `/etc/sudoers.d/archiso` | Passwordless live sudo |
| `/etc/lightdm/lightdm.conf.d/` | Live autologin |
| `/etc/systemd/system/getty@tty1.service.d/autologin.conf` | Live console autologin |
| `/etc/systemd/system/display-manager.service` | Live display-manager symlink; recreated by Calamares |
| `/etc/systemd/system/choose-mirror.service` | Live mirror selection |
| `/etc/systemd/system/pacman-init.service` | Live keyring initialization |
| `/etc/systemd/system/livecd-alsa-unmuter.service` | Live audio unmute |
| `/etc/systemd/system/livecd-talk.service` | Live speech/accessibility |
| `/etc/systemd/system/multi-user.target.wants/choose-mirror.service` | Live service enablement |
| `/etc/systemd/system/multi-user.target.wants/pacman-init.service` | Live service enablement |
| `/etc/systemd/system/multi-user.target.wants/livecd-talk.service` | Live service enablement |
| `/etc/systemd/system/multi-user.target.wants/systemd-networkd.service` | Live enablement; recreated by Calamares |
| `/etc/systemd/system/multi-user.target.wants/systemd-resolved.service` | Live enablement; recreated by Calamares |
| `/etc/systemd/system/sound.target.wants/livecd-alsa-unmuter.service` | Live audio target link |
| `/home/archiso` | Live home directory |
| `/etc/polkit-1/rules.d/50-calamares.rules` | Live-only passwordless installer launch |
| `/etc/security/faillock.conf` | Live-account lockout policy (working-tree addition) |

Live-intended content that is currently **not** excluded and therefore leaks into the target:

| Path | Issue / decision |
|---|---|
| `/etc/calamares/` | Installer configuration remains after the Calamares package is removed |
| `/root/customize_airootfs.sh` | Contains the live password hash; not excluded |
| `/etc/sysusers.d/99-live-user.conf` | Can recreate the live `archiso` group/memberships on the target |
| `/usr/local/bin/choose-mirror` | Live helper script |
| `/usr/local/bin/livecd-sound` | Live accessibility helper |
| `/usr/local/share/livecd-sound/` | Live accessibility assets |
| `/root/.zlogin` | Live accessibility shell fix |
| `/root/.gnupg/scdaemon.conf` | Live root GnuPG configuration |
| `/etc/systemd/journald.conf.d/volatile-storage.conf` | Target receives a volatile journal |
| `/etc/systemd/logind.conf.d/do-not-suspend.conf` | Target ignores suspend/hibernate keys |
| `/etc/systemd/resolved.conf.d/archiso.conf` | Decide whether target should keep live mDNS settings |
| `/etc/systemd/system/etc-pacman.d-gnupg.mount` | Live keyring mount; decide whether target needs it |
| `/etc/passwd`, `/etc/shadow` | Live user is removed and root password is set by Calamares; validate the result, do not exclude blindly |
| `/etc/hostname`, `/etc/motd` | Rewritten by Calamares / cleanup; validate the result |

Also currently retained in the target and requiring an explicit decision:

- `multi-user.target.wants/iwd.service`, `sshd.service`, `ModemManager.service`, and hypervisor/virtualization service links. Some are useful target services; some are live convenience. They are not live-only by accident, but they are not part of a minimal target either.
- `multi-user.target.wants/systemd-networkd.service` and `systemd-resolved.service` are excluded from the unpack, then re-enabled by Calamares. This duplication is intentional but must be validated in order.

Stale entries currently present in `unpackfs/exclude-list.txt` (path does not exist in the profile):

- `/root/.automated_script.sh`
- `/usr/local/bin/Installation_guide`
- `/etc/polkit-1/rules.d/49-nopasswd_global.rules`
- `/etc/systemd/system/multi-user.target.wants/getty@tty1.service`
- `/etc/systemd/system/multi-user.target.wants/livecd-alsa-unmuter.service`

Live-only packages (currently removed by Calamares cleanup):

- `calamares`
- `mkinitcpio-archiso`
- `livecd-sounds`

Target-only / future content (not yet modeled):

- KDE Plasma packages and SDDM.
- Echo OS `/etc/os-release`, logos, wallpapers, Plasma defaults, and skel files.
- Aira AI service, user session integration, and configuration.
- Target-only applications and services that should not be in the live image (requires an install-time application mechanism, because `unpackfs` copies the live root).

### 4.4 Shared build infrastructure

| Path | Responsibility |
|---|---|
| `build.sh` | Renders `pacman.conf`, then runs `sudo mkarchiso` |
| `scripts/render-pacman-conf.sh` | Substitutes the absolute local repository path into `profile/pacman.conf` |
| `profile/pacman.conf.in` | Source template for the build-time pacman configuration |
| `profile/pacman.conf` | Generated, machine-specific copy (currently tracked) |
| `profile/profiledef.sh` | ArchISO profile definition (identity, boot modes, image options, permissions) |
| `profile/packages.x86_64` | Merged x86_64 package list (currently hand-maintained) |
| `profile/packages.aarch64` | Merged aarch64 package list (currently hand-maintained) |
| `profile/bootstrap_packages` | ArchISO bootstrap package list |
| `packages/echo.db`, `packages/echo.files` | Tracked symlinks to local repository databases |
| `packages/echo.db.tar.zst`, `packages/echo.files.tar.zst` | Local repository metadata (gitignored) |
| `packages/README.md` | Local repository and PKGBUILD documentation |
| `.gitignore` | Ignores `out/`, `work/`, ISOs, package tarballs |
| `README.md` | Current build/install documentation |
| `out/`, `work/` | Build outputs (not copied to Desktop) |

### 4.5 Generated files that should stop being sources

- `profile/pacman.conf` (generate into the assembled profile).
- `profile/packages.x86_64` and `profile/packages.aarch64` (merge from component package manifests).
- The Calamares `unpackfs/exclude-list.txt` (derive from component live-only declarations plus a shared ISO-only list).
- The target service list in `services-systemd.conf` and the display manager in `displaymanager.conf` (derive from Core's desktop/service interface).
- Any future `os-release` or branding files that repeat product/version data (derive from one release source).

---

## 5. Findings and risks

| ID | Finding | Evidence | Impact | Required action |
|---|---|---|---|---|
| F-01 | Repository desktop is XFCE, task target is KDE Plasma | `packages.x86_64`, `lightdm.conf`, Calamares `displaymanager.conf` | A "KDE Echo OS" does not exist yet | Keep KDE as a separate feature change after modularization |
| F-02 | No Echo OS identity or branding | `profiledef.sh`, boot menus, Calamares `branding: default`, no `os-release` | The ISO presents as Arch Linux | Core owns identity/branding; add in a dedicated change |
| F-03 | No rEFInd live integration | ArchISO 91 has no rEFInd boot-mode function; ISO contains no `EFI/refind` | A live rEFInd menu cannot be enabled by config alone | Keep systemd-boot for live UEFI; use rEFInd on installed UEFI; document |
| F-04 | Installed system uses GRUB | `bootloader.conf: efiBootLoader: "grub"` | Preferred bootloader not implemented | Switch to Calamares `refind` for UEFI in a tested Install change; keep GRUB for BIOS |
| F-05 | Calamares branding is stock | `settings.conf: branding: default`; empty `airootfs/etc/calamares/branding/` | No Echo installer experience | Echo Install owns branding; add custom component |
| F-06 | Existing ISO is stale | 7 source files newer than ISO; `accountsservice` absent from ISO pkglist | The ISO does not represent the working tree | Commit changes, rebuild, retest |
| F-07 | Local repo diverges from GitHub | No remote; local HEAD 2026-10-21; GitHub HEAD 2026-08-06, different layout | Pushing could overwrite/conflict | Decide GitHub reconciliation before pushing; never force-push |
| F-08 | Critical work is uncommitted | 7 modified + 2 untracked files | Migration could lose the live-login fix | Commit on a dedicated branch before moving files |
| F-09 | `pacman.conf` is machine-specific and tracked | Contains `file:///home/ghost/Projects/echo-os/packages` | Wrong on any other checkout, including Desktop | Generate into `build/generated/profile`; stop tracking it |
| F-10 | Local package payloads are gitignored | `*.pkg.tar.*` ignored; DB symlinks tracked | Fresh clone cannot build offline | Add a local-repo build/check script; fail clearly if payload is missing |
| F-11 | Install is a live-root copy | `unpackfs.conf`; cleanup removes only 3 packages | Installed system inherits live tools, XFCE, live config | Model live/target scopes and generate the exclude list |
| F-12 | Live-only configuration leaks into target | `/etc/calamares/`, `/root/customize_airootfs.sh`, `/etc/sysusers.d/99-live-user.conf`, livecd scripts, `/root/.zlogin`, live journal/logind config are not excluded | Installer config, the live password-hash script, and live user groups can persist in the target | Generate the exclude list from component live-only declarations; add these paths and validate |
| F-13 | Desktop/service coupling in Installer | `displaymanager.conf`, `services-systemd.conf` hardcode LightDM | Switching to KDE/SDDM requires editing two components | Generate these from Core's desktop interface |
| F-14 | Live password hash duplicated and leaked | Hash appears in `etc/shadow` and `customize_airootfs.sh`; the script is not excluded from the target | Two sources can drift; the hash remains on the installed disk | One live-user source, generated outputs; exclude the script |
| F-15 | No automated tests/validation | No `tests/`; `mkarchiso` has no validate-only mode | Regressions are only found by a full build | Add assembly/validation tests and a VM test plan |
| F-16 | No CI | No workflow files | No repeatable checks | Add after component scripts exist |
| F-17 | Calamares cleanup uses `pacman -Rns calamares` | `shellprocess-cleanup.conf` | With KDE, Qt/KDE dependencies overlap; removal may be unsafe or incomplete | Validate target package manifest explicitly before switching to KDE |
| F-18 | `refindKernelList` missing | `bootloader.conf` has no such key | Calamares rEFInd install would not get kernel entries | Add when switching target bootloader to rEFInd |
| F-19 | BIOS has no rEFInd | rEFInd is UEFI-only | BIOS installs still need GRUB/syslinux | Keep GRUB as BIOS target fallback; document |
| F-20 | `unpackfs` paths are x86_64-hardcoded | `/arch/x86_64/airootfs.sfs`, `/arch/boot/x86_64` | aarch64 ISO install cannot work as-is | Make paths arch-aware during Install refactor |
| F-21 | Empty Calamares branding dir cannot be tracked | Git does not track empty directories | Branding path may be absent after clone | Add real branding files or `.gitkeep` |
| F-22 | `customize_airootfs.sh` is not executable in Git | mode `0644` | `mkarchiso` chmods it before running, so it works, but validation should enforce `0755` | Set executable bit; add permission validation |
| F-23 | `profile/grub/grub.cfg` is inactive | `bootmodes` has no grub | Dead configuration can drift | Boot component keeps it only as an optional future mode |
| F-24 | Boot menus and ISO use Arch identity | Titles, label, publisher, application | No Echo OS brand | Release identity source + Boot templates |
| F-25 | No KDE service defaults | No SDDM/NetworkManager/PipeWire config | KDE switch needs service design | Core owns service/desktop defaults |
| F-26 | VM tooling absent | No QEMU/libvirt/OVMF found | Cannot execute install/boot validation yet | Install/verify disposable VM tooling before Phase 7 |
| F-27 | No YAML parser/linter installed | PyYAML/yamllint absent | Calamares YAML cannot be linted with a standard tool | Use Calamares module metadata + a small check, or install tooling in a dedicated build env |
| F-28 | Local repo is unsigned/trust-all | `SigLevel = Optional TrustAll` | Supply-chain risk | Keep local-only; document; sign in a later hardening task |
| F-29 | Stale exclude-list entries | 5 paths in `unpackfs/exclude-list.txt` do not exist in the profile: `/root/.automated_script.sh`, `/usr/local/bin/Installation_guide`, `/etc/polkit-1/rules.d/49-nopasswd_global.rules`, `multi-user.target.wants/getty@tty1.service`, `multi-user.target.wants/livecd-alsa-unmuter.service` | The live/target boundary is not trustworthy; real leaks can hide behind dead entries | Generate and validate the list; fail on missing paths |
| F-30 | Live sysusers file is not excluded | `/etc/sysusers.d/99-live-user.conf` is in the profile but not in the exclude list | `systemd-sysusers` can recreate the `archiso` group/memberships after install | Treat it as live-only and validate the target account database |

No finding requires deleting or rewriting the working configuration.

---

## 6. Proposed three-component architecture

### 6.1 Structure (adapted to the actual repository)

```text
EchoOS-DEV/
├── components/
│   ├── echo-boot/
│   │   ├── manifest.conf
│   │   ├── config/
│   │   │   ├── boot-menu/
│   │   │   │   ├── efiboot/            # copied to profile/efiboot
│   │   │   │   ├── syslinux/           # copied to profile/syslinux
│   │   │   │   └── grub/               # copied to profile/grub
│   │   │   ├── initramfs/archiso.conf  # live initramfs config
│   │   │   └── refind/                 # installed-system assets, not live boot
│   │   ├── packages/
│   │   │   ├── live.x86_64
│   │   │   ├── target.x86_64
│   │   │   ├── live.aarch64
│   │   │   └── target.aarch64
│   │   ├── hooks/                      # optional assembly hooks, not ArchISO variables
│   │   ├── scripts/verify-boot.sh
│   │   └── README.md
│   │
│   ├── echo-install/
│   │   ├── manifest.conf
│   │   ├── calamares/
│   │   │   ├── settings.conf
│   │   │   ├── branding/
│   │   │   └── modules/
│   │   ├── config/
│   │   │   └── live/                   # polkit rule and other live-only installer config
│   │   ├── packages/
│   │   │   ├── live.x86_64             # calamares
│   │   │   └── PKGBUILD
│   │   ├── scripts/validate-calamares.sh
│   │   └── README.md
│   │
│   └── echo-core/
│       ├── manifest.conf
│       ├── airootfs/                   # common overlay: live + target
│       ├── live/                       # live-only overlay, excluded from target
│       ├── target/                     # optional post-install assets (future)
│       ├── packages/
│       │   ├── common.x86_64
│       │   ├── live.x86_64
│       │   ├── target.x86_64
│       │   ├── common.aarch64
│       │   ├── live.aarch64
│       │   └── target.aarch64
│       ├── services/                   # target service/desktop declarations
│       ├── defaults/                   # skel, os-release, desktop defaults
│       ├── config/                     # identity/branding inputs
│       └── README.md
│
├── build/
│   ├── config/
│   │   ├── release.conf                # product/release/ISO identity - one source
│   │   ├── pacman.conf.in              # build-time pacman config - one source
│   │   ├── live-user.conf              # live account identity - one source
│   │   ├── kernel-params.conf          # kernel parameters - one source
│   │   └── file-permissions.conf       # shared permission policy
│   ├── template/
│   │   ├── profiledef.sh               # ArchISO profile skeleton
│   │   └── bootstrap_packages
│   ├── generated/
│   │   └── profile/                    # assembled ArchISO profile (gitignored)
│   ├── lib/
│   │   ├── packages.sh
│   │   ├── overlay.sh
│   │   └── validate.sh
│   ├── assemble.sh
│   └── validate.sh
│
├── scripts/
│   ├── build.sh                        # thin wrapper: assemble -> validate -> mkarchiso
│   └── build-local-repo.sh
│
├── tests/
│   ├── fixtures/
│   ├── test-assemble.sh
│   ├── test-validate.sh
│   └── run.sh
│
├── docs/
│   ├── phase-1-architecture-report.md
│   ├── architecture.md
│   ├── components.md
│   └── testing.md
│
├── packages/                           # source of the local [echo] repo
│   ├── PKGBUILD                        # moved under echo-install, see note
│   ├── echo.db -> ...
│   └── ...
│
├── out/                                # final ISOs (gitignored)
├── work/                               # mkarchiso work dir (gitignored)
└── README.md
```

Notes on this adaptation:

- `build/profile/` in the requested layout is split into `build/template/` (inputs) and `build/generated/profile/` (output). This prevents assembly from modifying source files, as required by Phase 5.
- `build/config/` is the shared single-source layer. It is not a fourth component; it is build infrastructure.
- `hooks/` under Boot and Install are **assembly hooks** run by `assemble.sh`/`validate.sh`, not a new ArchISO configuration mechanism. ArchISO has no generic component-hook variable. No unsupported ArchISO variables will be introduced.
- The local `packages/` repository remains shared infrastructure. The Calamares `PKGBUILD` is owned by Echo Install; the built repository metadata is generated by `scripts/build-local-repo.sh`.

### 6.2 Component responsibilities

#### Echo Boot

Owns:

- Live ISO boot modes: `bios.syslinux` and `uefi.systemd-boot`.
- `efiboot/` loader entries and `syslinux/` menus, plus the inactive GRUB menu/loopback files.
- Live initramfs configuration (`mkinitcpio.conf.d/archiso.conf`).
- Kernel command-line policy (`kernel_params_x86_64` / `kernel_params_aarch64`).
- Boot artwork and boot-menu text.
- Boot-related package declarations (`syslinux`, `edk2-shell`, `memtest86+`, `refind`, `grub`).
- Installed-system bootloader policy (interface to Echo Install), including the UEFI rEFInd vs BIOS GRUB split.
- `scripts/verify-boot.sh` for pre-build and post-build EFI checks.

Does not own:

- The kernel, firmware, or microcode packages (Core owns them; Boot requires them).
- The live user or desktop services (Core).
- Calamares configuration (Install).

Technical decision:

- Keep **systemd-boot** for live UEFI. ArchISO 91 does not implement a rEFInd boot mode; changing `BOOTx64.EFI` to a rEFInd binary would bypass ArchISO's supported entry generation and is not acceptable without a separately approved, VM-tested design.
- Use **rEFInd** for the installed UEFI system after the refactor, through Calamares 3.4.2's supported `efiBootLoader: "refind"` path.
- Keep **GRUB** for installed BIOS systems. rEFInd is UEFI-only; BIOS still needs GRUB (or syslinux).
- Do not remove GRUB from the target package set while BIOS support is required.

#### Echo Install

Owns:

- Calamares `settings.conf`, modules, instances, and branding.
- Installer package recipe and package selection.
- Live-only installer launcher policy (polkit rule).
- The live/target boundary contract consumption: the generated exclude list, target package removal, and target cleanup.
- Partitioning, filesystem, UEFI/BIOS installation, user/locale/timezone/keyboard configuration.
- Bootloader installation through the Boot interface.
- Installer logging and failure handling (Calamares logs plus explicit validation).
- `scripts/validate-calamares.sh`.

Does not own:

- The desktop choice or target display manager (Core declares it; Install consumes it).
- Target service enablement policy (Core declares it; Install consumes it).
- The kernel/desktop packages (Core).
- The live boot chain (Boot).

Mandatory validation:

- Every module in `sequence` and `instances` must exist in the installed Calamares 3.4.2 module set.
- Every referenced config file must exist.
- Every branding component must exist.
- Every `unpackfs` source and exclude path must match the assembled profile.
- `efiBootLoader` must be a supported value and its required packages/config keys must be present.
- Module order must preserve the current working order until a change is tested.

#### Echo Core

Owns:

- Arch Linux base, kernel, firmware, microcode, and initramfs tooling.
- Desktop: currently XFCE/LightDM; target KDE Plasma/SDDM in a later feature change.
- Networking, audio, Bluetooth, printing, power, and system services.
- Target service declarations consumed by Install.
- System identity, `os-release`, hostname defaults, MOTD, and branding.
- Default applications and target package selection.
- Live-only operating-system overlay (live user, autologin, volatile journal, live services).
- Future Aira integration points (no AI implementation in this task).
- Installed-system defaults and maintenance.

Does not own:

- The live boot menus or bootloader policy (Boot).
- Calamares itself (Install).
- The build profile skeleton or pacman.conf (Shared build).

#### Shared build infrastructure

Owns:

- Release/version/identity source.
- Build-time `pacman.conf` source.
- Local `[echo]` repository build and metadata.
- ArchISO profile skeleton and generation.
- Package-list merging and deduplication.
- Overlay copying and conflict detection.
- Permission policy application.
- Generated exclude list and target manifest.
- Assembly and validation scripts.
- Tests, docs, and README.

### 6.3 Interface between components

Each component exposes a declarative, Bash-sourceable `manifest.conf` (no YAML parser dependency, no arbitrary build logic):

```bash
COMPONENT_NAME="echo-boot"
COMPONENT_VERSION="0.1.0"
REQUIRES=("echo-core")
PACKAGE_FILES=(
  "packages/live.x86_64"
  "packages/target.x86_64"
  "packages/live.aarch64"
  "packages/target.aarch64"
)
OVERLAY_DIRS=(
  "airootfs"     # common overlay
  "live"         # live-only overlay
)
ARCHISO_MAP=(
  "config/boot-menu/efiboot:efiboot"
  "config/boot-menu/syslinux:syslinux"
  "config/boot-menu/grub:grub"
)
LIVE_ONLY_PATHS_FILE="live-only.txt"
```

Rules:

- `PACKAGE_FILES` are newline-separated package lists. `#` comments and blank lines are allowed; one package name per line; architecture comes from the filename suffix.
- `OVERLAY_DIRS` are copied into `profile/airootfs/`. `live/` contents are also recorded in the generated target exclude list.
- `ARCHISO_MAP` destinations are restricted to real ArchISO locations (`efiboot`, `syslinux`, `grub`, `airootfs`, `bootstrap_packages`). No invented profile keys.
- A component may not silently override another component's file. Identical files are deduplicated; different files at the same destination fail assembly.
- Package duplicates are deduplicated; a package may not be declared in conflicting scopes without an explicit allow rule.
- Boot assets and Calamares assets are copied to their ArchISO locations; Core files are merged into `airootfs`.

### 6.4 Single sources of truth

| Fact | Single source | Generated consumers |
|---|---|---|
| Product name, release version, ISO name/label/publisher/application, install dir | `build/config/release.conf` | `build/generated/profile/profiledef.sh`, `os-release`, boot-menu templates, Calamares branding, README badges |
| Build-time pacman repositories | `build/config/pacman.conf.in` | `build/generated/profile/pacman.conf` |
| Package selection | `components/*/packages/*.{x86_64,aarch64}` | `build/generated/profile/packages.{x86_64,aarch64}`, target manifest |
| Live user name/UID/GID/password/groups | `build/config/live-user.conf` | `etc/passwd`, `etc/shadow`, `etc/sysusers.d/99-live-user.conf`, `customize_airootfs.sh` |
| Kernel parameters | `build/config/kernel-params.conf` | `profiledef.sh` `kernel_params_*`, boot entries |
| Live-only file boundary | `components/*/live-only.txt` + `build/config/iso-live-only.txt` | Calamares `unpackfs/exclude-list.txt` |
| File permissions | `build/config/file-permissions.conf` + component manifests | `profiledef.sh` `file_permissions` |
| Desktop and target services | `components/echo-core/services/` | Calamares `displaymanager.conf`, `services-systemd.conf` |
| Boot modes | `components/echo-boot/manifest.conf` | `profiledef.sh` `bootmodes` |
| Calamares module sequence | `components/echo-install/calamares/settings.conf` | Validation only; not regenerated |

During the behavior-preserving refactor, the release values remain exactly the current Arch values (`iso_name="archlinux"`, `ARCH_` label, Arch publisher/application). This preserves the ISO filename convention. Branding changes are a separate, reviewed change.

### 6.5 Assembly algorithm

`build/assemble.sh` must be deterministic and must not write to component sources:

1. Parse arguments (`--arch`, `--profile-out`, `--repo`, `--no-clean`).
2. Validate that all three component directories and manifests exist.
3. Read `build/config/release.conf`, `pacman.conf.in`, `kernel-params.conf`, `live-user.conf`, and `file-permissions.conf`.
4. Create a clean `build/generated/profile/` (refuse to follow symlinks outside it).
5. Copy the ArchISO skeleton from `build/template/`.
6. Render `profiledef.sh` from the template and release/boot/permission inputs.
7. Render `pacman.conf` from `pacman.conf.in` with the absolute path to the local repository.
8. Merge package lists by architecture and scope:
   - `common` + `live` + `target` -> live ISO package list (`packages.x86_64`).
   - `common` + `target` -> intended target package manifest (used for validation/cleanup).
   - Deduplicate; fail on malformed names or cross-scope conflicts.
9. Pre-scan all component overlays and `ARCHISO_MAP` destinations for file, symlink, directory, and case-insensitive EFI collisions.
10. Copy overlays in a fixed order (Core common, Core live, Boot, Install) only after the scan passes; preserve modes, symlinks, and executable bits.
11. Copy ArchISO-mapped boot assets to their supported locations.
12. Generate `airootfs/etc/calamares/modules/unpackfs/exclude-list.txt` from live-only declarations, and verify each path exists in the assembled airootfs.
13. Generate the target service and display-manager snippets from Core's declarations.
14. Apply shared and component `file_permissions`; reject chmod targets that are symlinks.
15. Write a build manifest (Git commit, component versions, tool versions, input checksums, package counts, resolved package list) into `build/generated/`.
16. Run `build/validate.sh` against the generated profile unless `--no-validate` is explicitly passed.
17. Optionally invoke `mkarchiso` only from `scripts/build.sh`, never from `assemble.sh`.

Failure behavior:

- Missing component, manifest, package file, boot file, or Calamares config: fail before creating output.
- Conflicting file ownership: fail with both component names and the destination path.
- Duplicate package with conflicting scope: fail.
- Malformed package name or unsupported architecture suffix: fail.
- Any generated file outside `build/generated/`: fail.
- Never delete or rewrite `components/`, `build/config/`, `build/template/`, or legacy `profile/`.

### 6.6 Conflict policy

- **Identical file, same content:** deduplicate; log the winning source.
- **Identical symlink, same target:** deduplicate.
- **Different content at the same destination:** hard failure.
- **Regular file vs directory at the same path:** hard failure.
- **Regular file vs symlink:** hard failure.
- **Case-only collision under `efiboot/`:** hard failure (FAT ESP is case-insensitive).
- **Same package in multiple components:** deduplicate if the scopes are compatible.
- **Package declared both live-only and target:** hard failure unless `build/config/package-policy.conf` explicitly allows it.
- **Unknown ArchISO mapping destination:** hard failure (prevents invented variables).

---

## 7. Smallest safe migration plan

The migration is behavior-preserving. KDE, Echo branding, rEFInd-on-target, and Aira are explicitly out of scope for the refactor and are separate follow-up changes.

### Step 0 - Freeze and preserve the current work

- Create a branch: `git switch -c refactor/three-components`.
- Commit the 9 outstanding changes as a live-session fix commit (or a small series). Do not push.
- Tag the pre-migration state: `baseline/pre-modular`.
- Record the current built ISO checksum and the current `profile/` tree hash.
- Do not delete `out/` or `work/`.

**Rollback:** `git switch main` or `git reset --hard baseline/pre-modular` (only after confirming no newer work). No source file is removed in this step.

### Step 1 - Add the skeleton and prove parity

- Add `components/`, `build/`, `tests/`, `docs/` with READMEs and empty manifests.
- Implement `build/assemble.sh` in a **legacy mode**: it can assemble directly from the existing `profile/` into `build/generated/profile/` without moving files.
- Add `build/validate.sh` with the checks that do not depend on componentization (package syntax, profile structure, Calamares module existence, boot-mode support).
- Prove: `build/generated/profile/` is byte-for-byte equivalent to `profile/` (except explicitly generated files) and `build/validate.sh` passes.

**Rollback:** delete the new directories; `build.sh` still uses `profile/`.

### Step 2 - Move Echo Boot

- `git mv profile/efiboot components/echo-boot/config/boot-menu/efiboot`
- `git mv profile/syslinux components/echo-boot/config/boot-menu/syslinux`
- `git mv profile/grub components/echo-boot/config/boot-menu/grub`
- `git mv profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf components/echo-boot/config/initramfs/archiso.conf`
- Extract boot package declarations into `components/echo-boot/packages/`.
- Add `scripts/verify-boot.sh`.
- Assemble and diff against the baseline profile.
- Do not change boot modes, menu text, or the systemd-boot/syslinux implementation.

**Rollback:** reverse the `git mv` and restore the extracted package lines.

### Step 3 - Move Echo Install

- `git mv profile/airootfs/etc/calamares components/echo-install/calamares`
- `git mv profile/airootfs/etc/polkit-1/rules.d/50-calamares.rules components/echo-install/config/live/`
- Move the Calamares `PKGBUILD` under `components/echo-install/packages/`.
- Add `scripts/validate-calamares.sh`.
- Generate the exclude list from live-only declarations; for parity, first confirm it exactly matches the current 24-line list.
- Assemble and diff. Do not change module order, branding, bootloader, or package behavior.

**Rollback:** reverse the moves; the current exclude list can be restored from Git.

### Step 4 - Move Echo Core

- `git mv` the remaining `profile/airootfs/` content into `components/echo-core/airootfs/` (common) and `components/echo-core/live/` (live-only).
- Split `packages.x86_64` and `packages.aarch64` into common/live/target lists without changing the union.
- Move `bootstrap_packages` into Core or the build template.
- Add the desktop/service declarations.
- Assemble and diff. The generated `packages.x86_64` must contain exactly the current 156 packages (or a reviewed, documented delta).

**Rollback:** reverse the moves and restore the package lists from Git.

### Step 5 - Move shared build configuration

- Move `profile/pacman.conf.in` to `build/config/pacman.conf.in`.
- Move `profile/profiledef.sh` to `build/template/profiledef.sh` and make it a generated template.
- Stop tracking `profile/pacman.conf`; generate it into `build/generated/profile/`.
- Add `build/config/release.conf`, `live-user.conf`, `kernel-params.conf`, and `file-permissions.conf`.
- Add `scripts/build-local-repo.sh` and validate the `[echo]` repository payload before assembly.
- Add `scripts/build.sh` as the only user-facing build entry point.

**Rollback:** keep the legacy `profile/` and `build.sh` in place until the new pipeline has produced a verified ISO.

### Step 6 - Validation and tests

- Implement `build/validate.sh` and `tests/` as described in Section 8.
- Make `scripts/build.sh` run `assemble.sh` and `validate.sh` before `mkarchiso`.
- Add a `build/generated/` ignore rule.
- Add documentation for component ownership, interfaces, and testing.

**Rollback:** `build.sh --legacy` continues to use the old profile.

### Step 7 - Build and VM test

- Build the ISO with the new pipeline in a clean work directory.
- Compare the ISO package list and boot layout with the baseline.
- Boot UEFI (systemd-boot) and BIOS (syslinux) in a disposable VM.
- Run Calamares on a virtual disk, install offline, reboot, and verify:
  - target user, sudo, groups;
  - target bootloader (GRUB on BIOS; GRUB on UEFI for parity, then rEFInd in a separate change);
  - networking, display manager, locale, timezone;
  - no live user, no live-only services, no `/etc/calamares` leftovers;
  - target package set matches the intended manifest.
- Only after this may the new pipeline become the default.

**Rollback:** keep the baseline ISO and legacy profile until the new ISO passes.

### Step 8 - Deprecate the legacy profile

- After a verified build, remove or archive `profile/` in a dedicated commit.
- Update the README and docs.
- Do not rename the ISO or introduce codenames.

### Follow-up changes (not part of this refactor)

1. **KDE Plasma** - replace XFCE/LightDM with Plasma/SDDM; update Core packages, services, and Calamares display-manager generation.
2. **Echo branding** - add Calamares branding, boot artwork/menu text, `os-release`, wallpapers, and product identity from the release source.
3. **rEFInd on the installed UEFI system** - switch `efiBootLoader` to `refind`, add `refindKernelList`, keep GRUB for BIOS, and VM-test both.
4. **Aira integration** - add Core integration points and services; no AI features in this task.
5. **Target package minimization** - replace the current "remove three packages" cleanup with a validated target manifest and explicit live-only removals.

---

## 8. Validation design

### 8.1 Checks to automate

| Area | Check |
|---|---|
| Components | All three component directories and manifests exist; required package lists and overlays exist; versions parse |
| Required files | `build/template/profiledef.sh`, `build/config/pacman.conf.in`, `airootfs/`, `packages.x86_64`, `pacman.conf` in the generated profile; Calamares `settings.conf`; boot loader entries |
| Package syntax | One package per line; no spaces or tabs; `#` comments only; valid package-name characters; no empty package names |
| Package duplicates | No duplicates within a file; report cross-component duplicates; fail on conflicting scopes |
| Boot config | `bootmodes` subset of ArchISO 91 supported modes; required `efiboot/`/`syslinux/` dirs; loader entries have `title`, `linux`, `initrd`, `options`; `%ARCH%`, `%INSTALL_DIR%`, `%ARCHISO_UUID%`, `%KERNEL_PARAMS%` placeholders are used only where ArchISO substitutes them |
| Installed bootloader | `efiBootLoader` is supported; `grub` packages present for BIOS; `refind` packages and `refindKernelList` present if rEFInd is selected; no `installHybridGRUB=true` with a non-GRUB loader |
| Calamares modules | Every `sequence`/`instances` module exists in `/usr/lib/calamares/modules/<name>/`; every instance config exists; `branding:` resolves to `default` or a component branding directory |
| Calamares paths | `unpackfs` sources match `install_dir` and architecture; exclude paths exist in the generated airootfs; `packages.conf` is intentionally a no-op or matches the target manifest |
| File conflicts | Pre-copy scan for regular file/directory/symlink conflicts; case-insensitive collisions under `efiboot`; duplicate ownership report |
| Permissions | `customize_airootfs.sh` is executable; all scripts that must run are `0755`; `file_permissions` targets exist; no chmod target is a symlink; `/etc/shadow` mode is `0400` |
| ArchISO profile | Required profile files exist; `profiledef.sh` passes `bash -n`; `pacman.conf` passes `pacman-conf --config`; generated `packages.x86_64` is non-empty; `airootfs` exists |
| Separation | Every live-only path is excluded; `/etc/calamares` and the live user are excluded; target services/display manager come from Core; no live-only package is in the target manifest |
| Reproducibility | Build manifest records Git commit, component versions, ArchISO/Calamares versions, input checksums, and resolved package list |

### 8.2 What cannot be validated statically

- ArchISO 91 has no `--validate-only` mode. A profile can only be fully validated by a real `mkarchiso` build.
- A successful build is not proof of boot or install success.
- Calamares YAML parsing is not available via PyYAML/yamllint on this host. Static checks will verify file existence and module names; full schema validation requires Calamares itself or a dedicated tooling environment.
- Bootloader installation and EFI NVRAM behavior require a VM.
- Offline installation requires booting the ISO and running Calamares on a virtual disk.

### 8.3 Planned commands (to be finalized in Phase 7)

```bash
cd ~/Desktop/EchoOS-DEV

# Static validation of components and generated profile
./build/assemble.sh
./build/validate.sh

# Build wrapper (assemble + validate + mkarchiso)
./scripts/build.sh

# Direct equivalent of the current build, using the generated profile
sudo mkarchiso -v \
  -w "$PWD/work" \
  -o "$PWD/out" \
  -C "$PWD/build/generated/profile/pacman.conf" \
  "$PWD/build/generated/profile"
```

Disposable VM test outline (tooling still to be installed/verified):

```bash
# Never point these commands at a host disk.
qemu-img create -f qcow2 /tmp/echoos-test.qcow2 40G

# UEFI boot with OVMF; use the distro-provided OVMF paths.
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=/tmp/echoos-OVMF_VARS.fd \
  -drive file=/tmp/echoos-test.qcow2,if=virtio \
  -cdrom "$PWD/out/archlinux-YYYY.MM.DD-x86_64.iso" -boot d
```

The OVMF paths, QEMU availability, and BIOS test command must be verified before claiming Phase 7 results.

---

## 9. Open decisions requiring approval

1. **rEFInd scope.** Approve the split: systemd-boot for the live UEFI ISO, rEFInd for the installed UEFI system, GRUB for installed BIOS. This is the only technically valid option found with ArchISO 91 and Calamares 3.4.2 without forking ArchISO.
2. **KDE timing.** Approve keeping the desktop switch out of the refactor. The repository is currently XFCE; changing the desktop and the build system in the same change would make parity testing unreliable.
3. **GitHub reconciliation.** Decide whether the Desktop/local history is authoritative. Do not force-push over `HomieTal/EchoOS-DEV`; publish a branch and review first.
4. **Target package model.** Approve the live/target scope model and the initial behavior-preserving union, or authorize a more aggressive target-only package design. The latter requires an install-time mechanism beyond the current `unpackfs` copy.
5. **Branding timing.** Approve keeping Arch identity for the refactor, then adding Echo branding in a dedicated change. The ISO filename convention (`archlinux-YYYY.MM.DD-x86_64.iso`) stays unchanged.
6. **Validation tooling.** Approve installing only the VM/tooling needed for Phase 7, or accept that Calamares YAML/boot/install validation is a documented manual step until that tooling exists.

---

## 10. Phase 1 conclusion

- No source configuration was modified.
- The existing architecture is understood and mapped.
- The three-component split is feasible without forking ArchISO.
- The smallest safe migration is a behavior-preserving refactor on a branch, with generated profile parity checks at every step.
- The current ISO is stale and must not be used as proof that the working tree is good.
- No ISO build, boot, or installation test was run for this report, so no claim is made that the current or proposed ISO works.

**Next action after approval:** Step 0 of the migration plan (branch, commit the outstanding live-session fix, tag `baseline/pre-modular`), then Step 1 (skeleton and parity harness). No component files should be moved before that.
