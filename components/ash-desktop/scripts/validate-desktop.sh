#!/usr/bin/env bash
# Ash Desktop component validation. Read-only; no ISO build, no root.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
COMP="$ROOT/components/ash-desktop"
fails=0
ok()   { printf 'OK   %s\n' "$*"; }
bad()  { printf 'FAIL %s\n' "$*" >&2; fails=$((fails + 1)); }

# --- required payload -------------------------------------------------------
files=(
  "README.md"
  "packages/packages.x86_64"
  "packages/packages.aarch64"
  "config/airootfs/etc/xdg/autostart/echoos-wallpaper.desktop"
  "config/airootfs/usr/local/bin/echoos-wallpaper-apply"
  "config/airootfs/usr/share/echoos/echo-mark.png"
  "config/airootfs/usr/share/wallpapers/EchoOS/metadata.json"
  "config/airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png"
  "config/live/etc/gdm/custom.conf"
  "config/live/etc/systemd/system/display-manager.service"
  "config/live/var/lib/AccountsService/users/archiso"
  "config/airootfs/usr/share/wayland-sessions/ash.desktop"
)
for f in "${files[@]}"; do
  if [[ -s "$COMP/$f" || -L "$COMP/$f" ]]; then ok "payload $f"; else bad "missing payload $f"; fi
done

# --- package contract --------------------------------------------------------
for arch in x86_64 aarch64; do
  m="$COMP/packages/packages.$arch"
  for p in gnome gdm; do
    grep -Fxq "$p" "$m" 2>/dev/null && ok "$arch declares $p" || bad "$arch missing $p"
  done
  if grep -Eq '^(plasma-meta|sddm|kwin|konsole|dolphin|xfce4|xfce4-goodies|lightdm|lightdm-gtk-greeter)$' "$m" 2>/dev/null; then
    bad "$arch still declares an XFCE/KDE/SDDM/LightDM package"
  else
    ok "$arch carries no XFCE/KDE/SDDM/LightDM packages"
  fi
done

# --- GDM configuration contract ----------------------------------------------
# GDM configuration is live-only: the installed target uses the GDM
# defaults (normal login screen) after the unpackfs exclusion.
live="$COMP/config/live/etc/gdm/custom.conf"
grep -Eq '^AutomaticLoginEnable=true$' "$live" && ok "live autologin is enabled" || bad "live autologin not enabled"
grep -Eq '^AutomaticLogin=archiso$' "$live" && ok "live autologin user is archiso" || bad "live autologin user wrong"
if find "$COMP/config/airootfs/etc/gdm" -print -quit 2>/dev/null | grep -q .; then
  bad "airootfs must not carry GDM configuration (live-only contract)"
else
  ok "GDM configuration is live-only"
fi

# --- Ash Desktop session identity --------------------------------------------
session="$COMP/config/airootfs/usr/share/wayland-sessions/ash.desktop"
grep -Eq '^Name=Ash Desktop$' "$session" && ok "session registers as 'Ash Desktop'" || bad "session name wrong"
grep -Eq '^Exec=gnome-session$' "$session" && ok "session starts gnome-session" || bad "session Exec wrong"
grep -Eq '^DesktopNames=GNOME;Ash$' "$session" && ok "session declares GNOME;Ash desktop names" || bad "session DesktopNames wrong"
accounts="$COMP/config/live/var/lib/AccountsService/users/archiso"
grep -Eq '^Session=ash$' "$accounts" && ok "live AccountsService session is ash" || bad "live AccountsService session wrong"

# --- wallpaper enforcement ---------------------------------------------------
apply="$COMP/config/airootfs/usr/local/bin/echoos-wallpaper-apply"
[[ -x "$apply" ]] && ok "wallpaper script is executable" || bad "wallpaper script lost its executable bit"
grep -Eq 'gsettings set org\.gnome\.desktop\.background picture-uri' "$apply" \
  && ok "wallpaper script sets the GNOME background" || bad "wallpaper script does not use gsettings"
grep -Fq '/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png' "$apply" \
  && ok "wallpaper script targets the Echo wallpaper" || bad "wallpaper script wallpaper wrong"
grep -Eq '^OnlyShowIn=GNOME;Ash;$' "$COMP/config/airootfs/etc/xdg/autostart/echoos-wallpaper.desktop" \
  && ok "wallpaper autostart is restricted to GNOME/Ash sessions" || bad "wallpaper autostart OnlyShowIn wrong"

# --- live display-manager link ----------------------------------------------
link="$COMP/config/live/etc/systemd/system/display-manager.service"
if [[ "$(readlink "$link" 2>/dev/null)" == "/usr/lib/systemd/system/gdm.service" ]]; then
  ok "live display-manager link points at gdm"
else
  bad "live display-manager link does not point at gdm"
fi

# --- no XFCE/SDDM payload remains ---------------------------------------------
if find "$COMP" \( -iname "*sddm*" -o -iname "*plasma*" -o -iname "*lightdm*" -o -iname "*xfce*" \) | grep -q .; then
  bad "XFCE/SDDM/LightDM/Plasma payload remains in the component"
else
  ok "no XFCE/SDDM/LightDM/Plasma payload remains"
fi

printf '\n'
if [[ "$fails" -ne 0 ]]; then
  printf 'ASH DESKTOP VALIDATION: FAILED (%d failure(s))\n' "$fails" >&2
  exit 1
fi
printf 'ASH DESKTOP VALIDATION: PASSED (Ash Desktop session / GDM)\n'
