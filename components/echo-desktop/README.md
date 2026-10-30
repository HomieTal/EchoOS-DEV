# Echo Desktop

Echo Desktop owns the graphical session of Echo OS:

- KDE Plasma 6 packages and Plasma applications;
- KWin, the Plasma Wayland session, and the SDDM display manager;
- the Echo OS SDDM theme, wallpaper, icons, fonts, and first-login branding;
- the live-session SDDM autologin policy;
- the enabled `display-manager.service` link for the live medium.

It depends on `echo-core` for the kernel, firmware, system services, live
account, and base system. It does **not** own or replace Core configuration.

## Boundaries

| Area | Owner |
| --- | --- |
| Kernel, firmware, initramfs tooling, systemd services, live account | `echo-core` |
| Boot menus, EFI assets, bootloader packages | `echo-boot` |
| Calamares, installer launcher, installer branding, target boot policy | `echo-install` |
| KDE Plasma, KWin, SDDM, wallpapers, themes, desktop apps, live autologin | `echo-desktop` |

The live-only SDDM autologin drop-in is excluded from the installed target by
the Installer-owned `unpackfs` exclude list. The installed system therefore
boots to the normal SDDM login screen.

Echo Desktop does not replace Core's `display-manager.service` provider
aliases. It supplies a live-only symlink from
`/etc/systemd/system/display-manager.service` to
`/usr/lib/systemd/system/sddm.service`; that symlink is excluded from the
installed target, where Calamares enables `sddm.service` directly.

## Layout

```text
packages/packages.x86_64       KDE Plasma + SDDM package set
packages/packages.aarch64      same desktop set for the ARM profile
config/airootfs/               common desktop payload (live and target)
config/live/                   live-only SDDM autologin and DM enable link
```

The component is assembled after `echo-core` and `echo-boot`, and before
`echo-install`.

## SDDM and the live session

- `config/airootfs/etc/sddm.conf` is common configuration. It selects
  `DisplayServer=wayland`, the `echoos` theme, and Plasma's Wayland session
  directories.
- `config/live/etc/sddm.conf.d/20-echoos-live-autologin.conf` is live-only
  autologin for `archiso` into `plasma.desktop`.
- `config/live/etc/systemd/system/display-manager.service` points the live
  medium at SDDM.
- `config/airootfs/usr/share/sddm/themes/echoos/` contains the greeter. Its
  `metadata.desktop` **must** declare `QtVersion=6` and
  `MainScript=Main.qml`. Without the Qt version, SDDM selects the Qt5 greeter
  (`/usr/bin/sddm-greeter`) and fails because the image has no Qt5 libraries.
  `build/validate.sh` enforces this.

## First-login branding

`config/airootfs/usr/local/bin/echoos-desktop-branding` runs from
`config/airootfs/etc/xdg/autostart/echoos-plasma-branding.desktop`. It applies
the Echo OS wallpaper once per user and writes
`$XDG_CONFIG_HOME/echoos-desktop-branded` only after
`plasma-apply-wallpaperimage` succeeds. It retries for up to 60 seconds because
autostart can run before `plasmashell` registers its D-Bus service. A failed
attempt leaves no marker, so a later login can still brand the desktop.

The shipped wallpaper is the user-provided asset and is intentionally left
unchanged.
