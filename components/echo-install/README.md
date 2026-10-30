# echo-install

Status: **Active.** Echo Install is a real assembly component merged into
`build/generated/profile` by `build/assemble.sh`. It owns the Calamares
installer, its branding, the live installer launcher, and installed-system
service/boot policy.

## Responsibilities

- Calamares module sequence and instances (`calamares/settings.conf`).
- Module configuration for partition/mount/fstab, locale/keyboard,
  users/sysusers/removeuser, machineid, initcpiocfg/initcpio, displaymanager,
  services-systemd, shellprocess (sysusers/refindboot/cleanup), packages
  (no-op), welcome/summary.
- Offline `unpackfs` from the live SquashFS with the live/target exclude list.
- Installed-system bootloader setup through rEFInd:
  `shellprocess-refindboot.conf` plus
  `config/rootfs/usr/local/sbin/echoos-refindconf-write`.
- Echo OS Calamares branding (`calamares/branding/echoos`).
- Live-only polkit rule for launching Calamares.
- Live installer launch integration: one launch path through
  `usr/local/bin/echoos-install-launcher` (single-instance guard, bounded
  session wait, failure log at `/tmp/echoos-install-launcher.log`, escalation
  via `pkexec` only), wired as the "Install Echo OS" desktop shortcut and the
  XDG autostart entry.
- Calamares package recipe and artifact.

Echo Install does **not** own the display manager, desktop session, live
account, or live boot menu. It configures the target to use the SDDM service
and the rEFInd bootloader, but the desktop itself belongs to `echo-desktop` and
the live boot menu belongs to `echo-boot`.

## Layout

```text
calamares/settings.conf              Calamares sequence and instances
calamares/modules/*.conf             module configuration (18 files)
calamares/modules/unpackfs/          live/target exclude list
calamares/branding/echoos/           Echo OS installer branding
config/live/                         live-only polkit and autostart
config/home/archiso/Desktop/         live "Install Echo OS" shortcut
config/rootfs/                       target/live helper scripts
packages/PKGBUILD                    Calamares recipe
packages/packages.x86_64             calamares + KF6 runtime deps
packages/packages.aarch64            empty (no installer for aarch64)
```

## Overlays

From `build/config/overlays.tsv`:

| Source prefix | Generated profile destination |
| --- | --- |
| `calamares` | `airootfs/etc/calamares` |
| `config/live` | `airootfs/etc` |
| `config/home` | `airootfs/home` |
| `config/rootfs` | `airootfs` |

## Installer flow

1. `unpackfs` copies the live SquashFS to the target.
2. `shellprocess@sysusers` repairs the target user database.
3. `removeuser` drops the live `archiso` user.
4. `users` creates the real account at uid 1000.
5. `displaymanager` configures SDDM with `/etc/sddm.conf`.
6. `services-systemd` enables networkd, resolved, and `sddm.service`.
7. `shellprocess@refindboot` runs `refind-install` in the target chroot and
   then `echoos-refindconf-write`, which publishes the removable-media
   fallback, writes a target-derived `/boot/refind_linux.conf`, copies the
   kernel and initramfs to the ESP root, and replaces the ESP's
   `refind.conf` with a deterministic manual boot entry.
8. `shellprocess@cleanup` and `umount` finish the job.

The `bootloader` module is intentionally not in the sequence. GRUB is not
shipped; rEFInd is installed by the dedicated shellprocess instance instead.

## Why the kernel lives on the ESP

rEFInd 0.14.2's ext4 driver can list an ext4 volume and read small files but
fails with "Not Found" when opening the multi-megabyte kernel image, so an
auto-detected `boot\vmlinuz-linux from root` entry cannot boot. The boot path
therefore never touches that driver: `echoos-refindconf-write` copies
`vmlinuz-linux` and `initramfs-linux.img` to the ESP root (which the firmware
reads natively), and the ESP `refind.conf` is a manual `menuentry "Echo OS"`
loading them with `root=UUID=` taken from the target's fstab. The same file is
written to `EFI/BOOT/refind.conf` for the fallback loader.

`/usr/share/libalpm/hooks/echoos-refind-sync.hook` re-runs
`echoos-refindconf-write` after every `linux` package install or upgrade, so
kernel updates republish the ESP copy instead of leaving it stale.

## Live/target boundary

`calamares/modules/unpackfs/exclude-list.txt` removes live-only state from the
installed target, including:

- live account home and desktop shortcut (`/home/archiso`)
- live SDDM autologin (`/etc/sddm.conf.d/20-echoos-live-autologin.conf`)
- live `display-manager.service` link and getty autologin
- live sudo, SSH, faillock, and polkit rules
- live mirror, pacman-init, and livecd units
- live installer launcher and autostart entry

The installed system therefore boots to the normal SDDM login screen with the
Echo OS theme, not to the live autologin session. The desktop theme and
wallpaper are common payload and remain installed.

## Installer launch path

Both the desktop shortcut and the XDG autostart entry execute
`/usr/local/bin/echoos-install-launcher`:

- refuses to start a second Calamares if one is already running;
- exits if no graphical session is present;
- waits a bounded 10 seconds for the session to settle;
- grants root X access through `xhost` for Calamares under Xwayland;
- logs to `/tmp/echoos-install-launcher.log`;
- escalates only through `pkexec` and the stock Calamares polkit action.

## Packages

`packages/packages.x86_64` declares `calamares` plus `kconfig`, `kcrash`, and
`kpackage`; the locally built Calamares package has an incomplete dependency
list, and the installer will not start without those KF6 libraries.
`packages/packages.aarch64` is intentionally empty.

## Dependencies

- **Echo Core:** live root, base system, users, filesystem utilities.
- **Echo Boot:** live rEFInd assets and the installed `refind` package.
- **Echo Desktop:** SDDM, Plasma Wayland session, and Echo theme referenced by
  `displaymanager.conf`.
- **Shared:** local repository, `build/assemble.sh`, and
  `build/template/profiledef.sh`.

## Validation

`./build/validate.sh` verifies the installer's SDDM selection, the enabled
`sddm.service`, the live/target exclusions, the Echo branding, the rEFInd
instance, the launcher, and the live shortcut/autostart. It does not run an
installation.

## Out of scope

- Desktop session configuration and SDDM theme implementation.
- Live boot-menu configuration.
- Package installation from the network; installation is offline by design.
