# mad-install (MAD Installer)

Status: **Active.** MAD Installer is the custom installer frontend of Echo OS
— *MAD Installer, Powered by Echo OS*. It is an independent, rebranded fork of
the retired `echo-install` component (copied and verified in Phase 2, see
`docs/COPY-VERIFICATION.md`). It is registered in
`build/config/components.tsv` at order 40 and is the installer used by the
current ISO.

## Identity

- Installer name: **MAD Installer**
- Parent OS: **Echo OS** (PRETTY_NAME `Echo OS 4.0 (Fox)`)
- Brand relationship: MAD Installer — Powered by Echo OS
- Logo: the official Echo OS mark, `calamares/branding/mad/echo-mark.svg`
  (verbatim copy of the master asset). Dark-surface variants re-color **only**
  the `#0b0b0b` paths to `#ffffff`; the teal pixels (`#019099`) are untouched
  and geometry is identical (`echo-mark-light.svg`).

## Responsibilities

Identical to `echo-install` (same Calamares 3.4.2 backend, same module
sequence), with MAD-specific branding and file identity:

- Calamares module sequence and instances (`calamares/settings.conf`,
  `branding: mad`).
- Module configuration for partition/mount/fstab, locale/keyboard,
  users/sysusers/removeuser, machineid, initcpiocfg/initcpio, displaymanager,
  services-systemd, shellprocess (sysusers/refindboot/cleanup), packages
  (no-op), welcome/summary.
- Offline `unpackfs` from the live SquashFS with the live/target exclude list.
- Installed-system rEFInd bootloader setup via
  `shellprocess-refindboot.conf` + `config/rootfs/usr/local/sbin/mad-refindconf-write`
  and the `mad-refind-sync.hook` libalpm hook (kernel updates re-publish the
  ESP copy).
- MAD Calamares branding (`calamares/branding/mad/`).
- Live-only polkit rule, desktop shortcut `mad-installer.desktop`, XDG
  autostart entry, and the single launch path through
  `usr/local/bin/mad-installer-launcher` (single-instance guard, bounded
  session wait, failure log at `/tmp/mad-installer-launcher.log`,
  escalation via `pkexec` only).
- `usr/local/bin/mad-installer-x11` — Qt xcb wrapper used by the launcher and
  as a fallback when starting Calamares directly (verified working, Phase 5 VM
  test, `docs/PHASE5-FINDINGS.md` F2).
- Calamares package recipe and artifact (`packages/`).

## Layout

```text
calamares/settings.conf              Calamares sequence and instances (branding: mad)
calamares/modules/*.conf             module configuration (18 files)
calamares/modules/unpackfs/          live/target exclude list
calamares/branding/mad/              MAD branding (see identity above)
config/live/                         live-only polkit and autostart
config/home/archiso/Desktop/         "MAD Installer" shortcut
config/rootfs/                       target/live helper scripts + hicolor app icon
docs/                                copy verification, findings, design tokens
packages/PKGBUILD                    Calamares recipe
packages/packages.x86_64             calamares + KF6 runtime deps
packages/packages.aarch64            empty (no installer for aarch64)
```

## Overlays (registered in `build/config/overlays.tsv`)

From `build/config/overlays.tsv`, same mapping as echo-install:

| Source prefix | Generated profile destination |
| --- | --- |
| `calamares` | `airootfs/etc/calamares` |
| `config/live` | `airootfs/etc` |
| `config/home` | `airootfs/home` |
| `config/rootfs` | `airootfs` |

## Installer flow

Unchanged from echo-install: `unpackfs` copies the live SquashFS;
`shellprocess@sysusers` repairs the target user database; `removeuser` drops
the live user; `users` creates the real account at uid 1000; `displaymanager`
configures LightDM; `services-systemd` enables networkd, resolved and
`lightdm.service`; `shellprocess@refindboot` finalizes boot setup;
`shellprocess@cleanup` and `umount` finish. The `bootloader` module is
intentionally not in the sequence.

Boot schemes (see `docs/PHASE5-FINDINGS.md` F3): **UEFI** installs rEFInd
into the target's ESP (with removable-media fallback and kernel/initramfs
published on the ESP root because rEFInd 0.14.x cannot read the modern ext4
root). The live ISO builds UEFI-only, so UEFI is the supported install path;
the inherited BIOS/GRUB target path remains in the helper but is not reachable
from the current live medium. The `bootloader` Calamares module is unused.

Boot-load details (why the kernel lives on the ESP, rEFInd ext4 driver
limitations, BIOS/GRUB path) are documented in the echo-install README and
`mad-refindconf-write` itself; MAD inherits them unchanged.

## Live/target boundary

`calamares/modules/unpackfs/exclude-list.txt` removes live-only state from the
installed target (live account home, live autologin, sudo/SSH/faillock/polkit
rules, mirror/pacman-init units, and MAD's own launcher/autostart). The
installed system boots to the normal LightDM login screen.

## Branding rules

- User-facing installer identity is **MAD Installer** everywhere (window,
  sidebar, slideshow, desktop entry, autostart).
- Operating-system identity stays **Echo OS** (welcome product name, boot
  entries, installed-system logs such as `/var/log/echoos-bootloader.log`,
  LightDM greeter references).
- No upstream Calamares artwork is shipped in this component. The Calamares
  runtime ships its own notices; licenses and attribution are preserved there.
- `uploadServer` is disabled (the previous branding uploaded install logs to a
  public pastebin).

## Dependencies

- **SPD Core (echo-core):** live root, base system, users, filesystem utilities.
- **Echo Boot:** live rEFInd assets and the installed `refind` package.
- **Echo Desktop:** XFCE, LightDM, and the Echo greeter/theme referenced by
  `displaymanager.conf`.
- **Shared:** local repository, `build/assemble.sh`, `build/template/profiledef.sh`.

## Validation

`build/validate.sh` validates the assembled MAD Installer contract. VM testing
uses disposable disks only.

## Out of scope

- Desktop session configuration and LightDM greeter implementation (echo-desktop).
- Live boot-menu configuration (echo-boot).
- Package installation from the network; installation is offline by design.
