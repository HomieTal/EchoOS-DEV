# Ash Desktop

Ash Desktop owns the graphical session of Echo OS:

- the **Ash Desktop session** — a GNOME-technology-base desktop
  (gnome-shell, GNOME Control Center, core GNOME apps from the Arch
  `gnome` group), presented everywhere under the Ash Desktop identity;
- **GDM** as the display manager, with the stock greeter;
- the Echo OS wallpaper and Echo mark;
- the live-session GDM autologin policy and the enabled
  `display-manager.service` link for the live medium.

It depends on `echo-core` for the kernel, firmware, system services, live
account, and base system. It does **not** own or replace Core configuration.

## Boundaries

| Area | Owner |
| --- | --- |
| Kernel, firmware, initramfs tooling, systemd services, live account | `echo-core` |
| Boot menus, EFI assets, bootloader packages | `echo-boot` |
| MAD Installer (Calamares), launcher, branding, target boot policy | `mad-install` |
| Ash Desktop: session, GDM, wallpapers, live autologin | `ash-desktop` |

## Layout

```text
packages/packages.x86_64       Ash Desktop package set
packages/packages.aarch64      same desktop set for the ARM profile
config/airootfs/               common desktop payload (live and target)
config/live/                   live-only GDM autologin and DM enable link
scripts/validate-desktop.sh    component-local validation
```

The component is assembled after `echo-core` and `echo-boot`, and before
`mad-install`.

## Session identity

`config/airootfs/usr/share/wayland-sessions/ash.desktop` registers the
session as **Ash Desktop** in GDM and other display managers. It starts
`gnome-session` and declares `DesktopNames=GNOME;Ash`, so GNOME-ecosystem
autostart entries keep working while the visible identity stays Ash
Desktop. This is the only session shipped; the stock `gnome` session
desktop files remain installed but Ash Desktop is the default entry point.

## GDM and the live session

- `config/live/etc/gdm/custom.conf` is the only GDM configuration shipped
  by this component: it enables `AutomaticLogin` for `archiso` on the
  live medium. GDM has no conf.d mechanism, so the live overlay carries
  the whole file. It is excluded from the installed target by the MAD
  Installer unpackfs exclude list, so an installed system uses the GDM
  defaults and always shows the normal GDM login screen.
- `config/live/var/lib/AccountsService/users/archiso` selects the Ash
  Desktop session (`Session=ash`) for the live autologin; GDM reads the
  preferred session from AccountsService. It is excluded from the
  installed target as well.
- `config/live/etc/systemd/system/display-manager.service` points the
  live medium at GDM; the MAD Installer enables `gdm.service` directly
  on the installed target.

## Desktop defaults

`config/airootfs/usr/local/bin/echoos-wallpaper-apply` (autostarted via
`config/airootfs/etc/xdg/autostart/echoos-wallpaper.desktop`,
`OnlyShowIn=GNOME;Ash;`) applies the Echo OS wallpaper to every Ash
Desktop session by setting `org.gnome.desktop.background picture-uri` and
`picture-uri-dark` with `gsettings`, so first login lands on a branded
desktop on both the live medium and installed systems.

## Wallpaper

`config/airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png`
is the default Echo OS wallpaper (a blue geometric artwork). It is applied to
every Ash Desktop session — live and installed users alike — by the wallpaper
autostart described above. It carries no third-party content.
