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
desktop on both the live medium and installed systems. The same script
also sets `org.gnome.desktop.screensaver picture-uri`/`picture-uri-dark`,
which is what the GNOME **lock screen** draws — without those keys the
lock screen falls back to the shell's built-in (Arch) background.

## Wallpaper

Two Echo OS wallpaper assets ship in this component, neither carrying
third-party content:

- `config/airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png` —
  the desktop wallpaper (blue geometric artwork);
- `config/airootfs/usr/share/wallpapers/EchoOS-Lock/contents/images/1600x900.png` —
  the default lock-screen artwork.

The three wallpaper surfaces are configured independently:

| Surface | Mechanism |
| --- | --- |
| Desktop background | per-session `gsettings` (autostart script, above) |
| Lock screen | per-session `gsettings`, `org.gnome.desktop.screensaver`, → EchoOS-Lock artwork (same script) |
| GDM login screen | system dconf defaults for the greeter, `etc/dconf/db/gdm.d/00-echoos-branding` + `etc/dconf/profile/gdm` |

The GDM greeter reads its dconf through the `gdm` profile. The gdm package
ships `/usr/share/dconf/profile/gdm` without a system db, so this component
overrides the profile in `/etc/dconf/profile/gdm` (dconf reads `/etc`
before `/usr/share`; nothing package-owned is touched) to declare
`system-db:gdm`, then brands it via `gdm.d`. On GNOME 49+ the greeter draws
a styled login dialog without a wallpaper, so the keyfile instead clears
`org.gnome.login-screen logo` — removing the upstream Arch logo that Arch
bakes into the compiled schema defaults — and pre-seeds the background and
screensaver keys with the Echo assets should a greeter ever draw them.

## Ash Panel (top panel)

`config/airootfs/usr/share/gnome-shell/extensions/ash-panel@echoos/`
is a small GNOME Shell extension that restyles the stock top panel as the
Ash Desktop panel: a dark translucent (glass) background —
`rgba(20, 20, 24, 0.70)`, `0.80` while a maximized window has focus —
with a subtle white bottom border and 0 radius. Only `#panel`'s own
background is overridden (via a class stylesheet, no container opacity),
so icons, text and indicators stay fully opaque.

The pinned-taskbar behaviour itself is stock GNOME Shell: the panel never
auto-hides, reserves struts so maximized windows stop below it, and stays
in place across workspace switches, screen lock/unlock, and resolution
changes. No dock/panel extension is installed. The extension declares
`"session-modes": ["user"]`, so it is unloaded on the lock screen and the
GDM greeter (those keep the stock shell theme).

The extension is enabled for all users by a system dconf default:
`etc/dconf/profile/user` declares `system-db:local`, and
`etc/dconf/db/local.d/00-ash-shell` sets
`org.gnome.shell enabled-extensions` (users may still override it).

## dconf compilation

dconf clients read compiled binary databases, but the assembly has no
image-build hook to run `dconf update`. `etc/systemd/system/echoos-dconf-update.service`
(a oneshot unit, wanted by `sysinit.target`, enabled via a symlink) runs
`dconf update` once per boot before GDM starts, compiling `local.d` and
`gdm.d`. It is idempotent and near-instant.

## Validation

- `scripts/validate-desktop.sh` — component payload/contract checks.
- `scripts/validate-branding.sh` — wallpaper/panel/branding checks.
  Repository mode by default; `--system` verifies the booted system
  (compiled dconf dbs, session gsettings values, GDM greeter defaults,
  extension install and shell-version compatibility).
