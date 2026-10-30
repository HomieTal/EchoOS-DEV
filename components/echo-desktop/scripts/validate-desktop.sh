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
  "airootfs/etc/sddm.conf"
  "airootfs/etc/sddm.conf.d/10-echoos-live-autologin.conf"
  "airootfs/etc/systemd/system/display-manager.service"
  "airootfs/etc/xdg/kdeglobals"
  "airootfs/etc/xdg/plasma-workspace/env/20-echoos-session.sh"
  "airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/metadata.json"
  "airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/defaults"
  "airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js"
  "airootfs/usr/share/wallpapers/EchoOS/metadata.json"
  "airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png"
  "airootfs/usr/share/sddm/themes/breeze/theme.conf.user"
  "airootfs/home/archiso/.config/plasma-welcomerc"
)
for f in "${files[@]}"; do
  [[ -s "$COMP/$f" ]] || [[ -L "$COMP/$f" ]] && ok "payload $f" || bad "missing payload $f"
done

# --- display manager wiring -------------------------------------------------
link="$COMP/airootfs/etc/systemd/system/display-manager.service"
if [[ -L "$link" && "$(readlink "$link")" == "/usr/lib/systemd/system/sddm.service" ]]; then
  ok "display-manager.service -> sddm.service"
else
  bad "display-manager.service must point at sddm.service"
fi

session="$(sed -n 's/^Session=//p' "$COMP/airootfs/etc/sddm.conf.d/10-echoos-live-autologin.conf")"
[[ "$session" == "plasma.desktop" ]] && ok "SDDM autologin session $session" || bad "SDDM autologin session is '$session'"
grep -q '^User=archiso$' "$COMP/airootfs/etc/sddm.conf.d/10-echoos-live-autologin.conf" && ok "SDDM autologin user archiso" || bad "SDDM autologin user missing"
# /etc/sddm.conf is read after /etc/sddm.conf.d/*.conf by SDDM.
if grep -qE '^\[Autologin\]' "$COMP/airootfs/etc/sddm.conf"; then
  bad "/etc/sddm.conf [Autologin] would override the live autologin drop-in"
else
  ok "/etc/sddm.conf does not override live autologin"
fi
grep -q '^LastSeenVersion=9999$' "$COMP/airootfs/home/archiso/.config/plasma-welcomerc" \
  && ok "live Welcome Center suppressed" || bad "live plasma-welcomerc missing LastSeenVersion=9999"

# --- package manifest -------------------------------------------------------
manifest="$COMP/packages/packages.x86_64"
for pkg in plasma-meta sddm pipewire wireplumber xdg-desktop-portal-kde xorg-xwayland xcb-util-cursor; do
  grep -qx "$pkg" "$manifest" && ok "package $pkg" || bad "package $pkg not declared"
done
if grep -qxE 'lightdm|lightdm-gtk-greeter|xfce4-session|xfdesktop|xfwm4|thunar|exo|garcon|tumbler' "$manifest"; then
  bad "desktop manifest still declares XFCE/LightDM packages"
else
  ok "desktop manifest free of XFCE/LightDM packages"
fi

# --- metadata JSON ----------------------------------------------------------
for j in \
  "airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/metadata.json" \
  "airootfs/usr/share/wallpapers/EchoOS/metadata.json"; do
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$COMP/$j" \
    && ok "valid JSON $j" || bad "invalid JSON $j"
done

# --- look and feel references ----------------------------------------------
grep -q 'LookAndFeelPackage=org.echoos.desktop' "$COMP/airootfs/etc/xdg/kdeglobals" && ok "system LookAndFeelPackage set" || bad "system LookAndFeelPackage missing"
grep -q 'org.kde.plasma.desktop.defaultPanel' "$COMP/airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" && ok "panel layout template referenced" || bad "panel layout template missing"
defaults="$COMP/airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/defaults"
grep -q '^Image=file:///usr/share/wallpapers/EchoOS$' "$defaults" && ok "Echo OS wallpaper default" || bad "Echo OS wallpaper default missing or not a package URL"
layout="$COMP/airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js"
grep -q "writeConfig('Image', 'file:///usr/share/wallpapers/EchoOS')" "$layout" && ok "layout writes Echo OS wallpaper" || bad "layout does not write Echo OS wallpaper"

if [[ $fails -eq 0 ]]; then
  echo "ECHO-DESKTOP VALIDATION: PASSED"
  exit 0
fi
echo "ECHO-DESKTOP VALIDATION: FAILED ($fails)" >&2
exit 1
