# echo-desktop

Owns the Echo OS **graphical environment**: KDE Plasma, SDDM, the graphical
session, Echo OS desktop defaults/branding, wallpapers, and desktop-level
applications. It depends on `echo-core` for the OS runtime and must not
replace core system configuration.

## Responsibilities

- KDE Plasma 6 / KWin / Plasma workspace packages (`plasma-meta`), Plasma
  session helpers, Wayland support and XWayland.
- SDDM as the display manager, including live autologin, the
  `display-manager.service` link, and the SDDM theme background.
- Audio and portal plumbing that only exists for the desktop session:
  PipeWire/WirePlumber, `xdg-desktop-portal{-kde}`, polkit KDE agent.
- Echo OS look-and-feel (`/usr/share/plasma/look-and-feel/org.echoos.desktop`),
  panel layout template, colour/icon defaults and wallpapers.
- Desktop applications and launchers owned by the desktop (Dolphin, Konsole,
  Kate, Ark).
- Desktop-session environment (`/etc/xdg/plasma-workspace/env`).

## What this component does NOT own

| Concern | Owner |
| --- | --- |
| Kernel, firmware, base, initramfs, mkinitcpio, live account | `echo-core` |
| Network stack (systemd-networkd, iwd, ModemManager), sshd, firewall-less base policy | `echo-core` |
| Calamares, its modules, branding, live installer autostart, "Install Echo OS" shortcut | `echo-install` |
| rEFInd, EFI assets, boot loader menus | `echo-boot` |
| Profile assembly, package merging, local repo, ISO build | shared `build/` |

The Calamares autostart entry (`/etc/xdg/autostart/echoos-install.desktop`) is
installer-owned but only works because this component provides a running
Plasma session. That is a dependency, not duplicated ownership.

## Layout

| Path | Destination in generated profile |
| --- | --- |
| `airootfs/` | `airootfs/` |
| `packages/packages.<arch>` | merged into `packages.<arch>` |

## Live vs installed behaviour

- **Live**: SDDM autologins `archiso` into `plasma.desktop`, Plasma applies the
  Echo OS look-and-feel and wallpaper, and the installer autostarts once
  (single-instance guarded by `/usr/local/bin/echoos-install-launcher`).
  The live user's `~/.config/plasma-welcomerc` suppresses Plasma's first-run
  Welcome Center so it cannot cover the installer; `/home/archiso` is excluded
  from the installed system, so new installations keep the normal Welcome
  Center.
- **Installed**: `/etc/sddm.conf.d/` is excluded by the installer, so the target
  shows a normal SDDM login. `/etc/xdg/kdeglobals` and the Echo OS look-and-feel
  package remain, so every new user gets the Echo OS defaults.

SDDM reads `/etc/sddm.conf` **after** `/etc/sddm.conf.d/*.conf`, so the root
file must not contain an `[Autologin]` section: empty `User=`/`Session=` keys
there would override the live drop-in and leave the ISO at the greeter. The
file is kept (without `[Autologin]`) because Calamares' displaymanager module
writes the installed system's autologin there.

## Wayland / X11

The live session defaults to Plasma's Wayland session (`plasma.desktop`), with
XWayland for X11 clients. Plasma 6.8 no longer ships an X11 session, so there is
no `plasmax11.desktop`; the SDDM autologin file documents this explicitly. The
installer launcher forwards `DISPLAY`, `XAUTHORITY` and `XDG_RUNTIME_DIR`
through `pkexec` (which otherwise strips them) and the installer-owned wrapper
forces `QT_QPA_PLATFORM=xcb`, so Calamares runs inside XWayland. Desktop
packages include `xcb-util-cursor`, which Qt's xcb platform plugin requires.

## Validation

```bash
components/echo-desktop/scripts/validate-desktop.sh
```

The script checks the component payload, SDDM session wiring (including that
`/etc/sddm.conf` does not mask live autologin), look-and-feel metadata, the
Echo OS wallpaper default and layout, live Welcome Center suppression, and
that no XFCE/LightDM remnants are declared.
