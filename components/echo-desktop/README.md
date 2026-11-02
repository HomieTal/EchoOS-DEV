# Echo Desktop

Echo Desktop owns the graphical session of Echo OS:

- the **default ArchISO XFCE desktop environment** (XFCE 4 + goodies set),
  matching the official Arch Linux XFCE ISO;
- **LightDM** with the `lightdm-gtk-greeter`, Echo-branded;
- the Echo OS wallpaper and Echo mark;
- the live-session LightDM autologin policy and the enabled
  `display-manager.service` link for the live medium.

It depends on `echo-core` for the kernel, firmware, system services, live
account, and base system. It does **not** own or replace Core configuration.

## Boundaries

| Area | Owner |
| --- | --- |
| Kernel, firmware, initramfs tooling, systemd services, live account | `echo-core` |
| Boot menus, EFI assets, bootloader packages | `echo-boot` |
| MAD Installer (Calamares), launcher, branding, target boot policy | `mad-install` |
| XFCE, LightDM, wallpapers, greeter branding, live autologin | `echo-desktop` |

## Layout

```text
packages/packages.x86_64       XFCE + LightDM package set
packages/packages.aarch64      same desktop set for the ARM profile
config/airootfs/               common desktop payload (live and target)
config/live/                   live-only LightDM autologin and DM enable link
scripts/validate-desktop.sh    component-local validation
```

The component is assembled after `echo-core` and `echo-boot`, and before
`mad-install`.

## LightDM and the live session

- `config/airootfs/etc/lightdm/lightdm.conf` is common configuration:
  `lightdm-gtk-greeter`, `user-session=xfce`, `/etc/lightdm/Xsession`.
- `config/airootfs/etc/lightdm/lightdm-gtk-greeter.conf` brands the greeter:
  the Echo wallpaper as background and the Echo mark as logo.
- `config/live/etc/lightdm/lightdm.conf.d/20-autologin.conf` is live-only
  autologin for `archiso` into the `xfce` session. It is excluded from the
  installed target by the MAD Installer unpackfs exclude list, so an installed
  system always shows the normal LightDM login screen.
- `config/live/etc/systemd/system/display-manager.service` points the live
  medium at LightDM; the MAD Installer enables `lightdm.service` directly on
  the installed target.

## Desktop defaults

`config/airootfs/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml`
applies the Echo OS wallpaper to newly created user accounts via XFCE's
xfconf defaults, so first login lands on a branded desktop without any
scripting.

## Wallpaper

`config/airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png`
is an original Echo OS asset generated from the official Echo mark
(`mad-install/calamares/branding/mad/echo-mark.svg`): a dark surface with the
brand teal (`#019099`) glow and the centered mark. It carries no third-party
content.
