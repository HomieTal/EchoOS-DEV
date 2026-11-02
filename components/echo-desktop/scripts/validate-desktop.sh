#!/usr/bin/env bash
# Echo Desktop component validation. Read-only; no ISO build, no root.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
COMP="$ROOT/components/echo-desktop"
fails=0
ok()   { printf 'OK   %s\n' "$*"; }
bad()  { printf 'FAIL %s\n' "$*" >&2; fails=$((fails + 1)); }

# --- required payload -------------------------------------------------------
files=(
  "README.md"
  "packages/packages.x86_64"
  "packages/packages.aarch64"
  "config/airootfs/etc/lightdm/lightdm.conf"
  "config/airootfs/etc/lightdm/lightdm-gtk-greeter.conf"
  "config/airootfs/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
  "config/airootfs/usr/share/echoos/echo-mark.png"
  "config/airootfs/usr/share/wallpapers/EchoOS/metadata.json"
  "config/airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png"
  "config/live/etc/lightdm/lightdm.conf.d/20-autologin.conf"
  "config/live/etc/systemd/system/display-manager.service"
)
for f in "${files[@]}"; do
  if [[ -s "$COMP/$f" || -L "$COMP/$f" ]]; then ok "payload $f"; else bad "missing payload $f"; fi
done

# --- package contract --------------------------------------------------------
for arch in x86_64 aarch64; do
  m="$COMP/packages/packages.$arch"
  for p in xfce4 xfce4-goodies lightdm lightdm-gtk-greeter; do
    grep -Fxq "$p" "$m" 2>/dev/null && ok "$arch declares $p" || bad "$arch missing $p"
  done
  if grep -Eq '^(plasma-meta|sddm|kwin|konsole|dolphin)$' "$m" 2>/dev/null; then
    bad "$arch still declares a KDE/SDDM package"
  else
    ok "$arch carries no KDE/SDDM packages"
  fi
done

# --- LightDM configuration contract -----------------------------------------
common="$COMP/config/airootfs/etc/lightdm/lightdm.conf"
grep -Eq '^greeter-session=lightdm-gtk-greeter$' "$common" \
  && ok "greeter-session is lightdm-gtk-greeter" || bad "greeter-session wrong"
grep -Eq '^user-session=xfce$' "$common" && ok "user-session is xfce" || bad "user-session wrong"

greeter="$COMP/config/airootfs/etc/lightdm/lightdm-gtk-greeter.conf"
grep -Eq '^background=/usr/share/wallpapers/EchoOS/' "$greeter" \
  && ok "greeter uses the Echo wallpaper" || bad "greeter background wrong"
grep -Eq '^logo=/usr/share/echoos/echo-mark\.png$' "$greeter" \
  && ok "greeter uses the Echo mark" || bad "greeter logo wrong"

live="$COMP/config/live/etc/lightdm/lightdm.conf.d/20-autologin.conf"
grep -Eq '^autologin-user=archiso$' "$live" && ok "live autologin user is archiso" || bad "live autologin user wrong"
grep -Eq '^autologin-session=xfce$' "$live" && ok "live autologin session is xfce" || bad "live autologin session wrong"

# --- live display-manager link ----------------------------------------------
link="$COMP/config/live/etc/systemd/system/display-manager.service"
if [[ "$(readlink "$link" 2>/dev/null)" == "/usr/lib/systemd/system/lightdm.service" ]]; then
  ok "live display-manager link points at lightdm"
else
  bad "live display-manager link does not point at lightdm"
fi

# --- no SDDM payload remains -------------------------------------------------
if find "$COMP" -iname "*sddm*" -o -iname "*plasma*" | grep -q .; then
  bad "SDDM/Plasma payload remains in the component"
else
  ok "no SDDM/Plasma payload remains"
fi

printf '\n'
if [[ "$fails" -ne 0 ]]; then
  printf 'ECHO DESKTOP VALIDATION: FAILED (%d failure(s))\n' "$fails" >&2
  exit 1
fi
printf 'ECHO DESKTOP VALIDATION: PASSED (XFCE 4 / LightDM)\n'
