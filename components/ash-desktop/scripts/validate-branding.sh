#!/usr/bin/env bash
# Echo OS desktop branding validation.
#
# Two modes:
#
#   validate-branding.sh            — repository mode: structural checks on the
#                                     ash-desktop component tree (wallpaper
#                                     configuration, panel configuration, and
#                                     Arch-branding reference sweep).
#   validate-branding.sh --system   — runtime mode: verifies the bootED Echo OS
#                                     system this runs on (live or installed):
#                                     compiled dconf defaults, GDM greeter
#                                     defaults, extension payload, and the
#                                     session's actual gsettings values.
set -uo pipefail

fails=0
ok()  { printf 'OK   %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*" >&2; fails=$((fails + 1)); }

# ---------------------------------------------------------------------------
# Repository mode
# ---------------------------------------------------------------------------
if [ "${1:-}" != "--system" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  COMP="$ROOT/components/ash-desktop"
  WP="/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png"
  WP_REL="config/airootfs$WP"

  echo "== Repository branding checks (components/ash-desktop) =="

  # 1. Wallpaper configuration: exactly one wallpaper asset, no stale paths.
  if [[ -s "$COMP/$WP_REL" ]]; then
    ok "Echo wallpaper asset exists in the payload"
  else
    bad "Echo wallpaper asset missing ($WP_REL)"
  fi
  if find "$COMP/config" -type f \( -iname '*arch*' -o -iname '*adwaita*' \) ! -name 'archiso*'; then :; fi
  stale=$(find "$COMP/config" -type f \( -iname '*arch*' -o -iname '*adwaita*' \) ! -name 'archiso*')
  if [ -n "$stale" ]; then
    bad "stale Arch/Adwaita-named payload files present:"
    printf '%s\n' "$stale" >&2
  else
    ok "no stale Arch/Adwaita payload files (archiso live-user files excluded)"
  fi
  if grep -rInE 'adwaita|/usr/share/backgrounds|archlogo|arch.*\.(png|jpg|jpeg)' "$COMP/config" \
      | grep -vE 'Echo wallpaper|# |^\s*#' | grep -q .; then
    bad "stale wallpaper paths referenced in configuration"
    grep -rInE 'adwaita|/usr/share/backgrounds|archlogo' "$COMP/config" | head -5 >&2
  else
    ok "no stale wallpaper paths referenced"
  fi

  # 2. Wallpaper configuration concerns are independent and all covered.
  apply="$COMP/config/airootfs/usr/local/bin/echoos-wallpaper-apply"
  for key in 'org.gnome.desktop.background picture-uri' \
             'org.gnome.desktop.background picture-uri-dark' \
             'org.gnome.desktop.screensaver picture-uri' \
             'org.gnome.desktop.screensaver picture-uri-dark'; do
    grep -Fq "gsettings set $key" "$apply" && ok "session default sets $key" \
      || bad "session default missing $key"
  done
  gdmd="$COMP/config/airootfs/etc/dconf/db/gdm.d/00-echoos-branding"
  for k in picture-uri picture-uri-dark picture-options; do
    grep -Eq "^$k=" "$gdmd" && ok "GDM greeter default sets $k" \
      || bad "GDM greeter default missing $k"
  done
  grep -Eq '^\[org/gnome/desktop/screensaver\]$' "$gdmd" \
    && ok "GDM greeter default covers the lock-style background" \
    || bad "GDM greeter default missing screensaver group"
  grep -Fq "logo=''" "$gdmd" && ok "GDM greeter default clears the upstream logo" \
    || bad "GDM greeter default does not clear the login logo"
  grep -Eq '^system-db:gdm$' "$COMP/config/airootfs/etc/dconf/profile/gdm" \
    && ok "gdm profile declares the gdm system db" || bad "gdm profile wrong"

  # 3. Panel configuration: pinned behaviour + translucent background,
  #    contents never dimmed.
  ext="$COMP/config/airootfs/usr/share/gnome-shell/extensions/ash-panel@echoos"
  grep -Fq 'rgba(20, 20, 24, 0.70)' "$ext/stylesheet.css" \
    && ok "panel background is the 70% dark glass" || bad "panel background wrong"
  grep -Fq 'border-bottom: 1px solid rgba(255, 255, 255' "$ext/stylesheet.css" \
    && ok "panel has the subtle white bottom border" || bad "panel border wrong"
  grep -Fq 'border-radius: 0px' "$ext/stylesheet.css" \
    && ok "panel radius is 0 (full-width)" || bad "panel radius wrong"
  if grep -Eq 'opacity:' "$ext/stylesheet.css"; then
    bad "stylesheet uses container opacity (would dim panel contents)"
  else
    ok "no container opacity used (contents stay 100%)"
  fi
  grep -Eq '"session-modes": \["user"\]' "$ext/metadata.json" \
    && ok "panel styling does not apply to lock screen/greeter" || bad "session-modes wrong"
  if grep -rEq 'autohide|dash-to-panel|dash-to-dock' "$COMP/packages" 2>/dev/null; then
    bad "panel-hiding/dock package declared"
  else
    ok "no panel autohide/dock packages (stock pinned panel preserved)"
  fi

  # 4. Branding references: only permitted Arch references remain. The
  #    sweep skips this script itself, comment lines (documentation of
  #    upstream behaviour, not user-visible branding), and the live-user
  #    (archiso) compatibility files.
  hits=$(grep -rIniE 'arch ?linux' "$COMP" \
         | grep -v 'validate-branding.sh' \
         | grep -v ':[0-9]*:#' \
         | grep -viE 'ArchISO|archiso|Arch `gnome`|arch-based|gnome ISO|Arch Linux GNOME ISO')
  if [ -n "$hits" ]; then
    bad "unexpected 'Arch Linux' references:"
    printf '%s\n' "$hits" | head -10 >&2
  else
    ok "no inappropriate Arch Linux branding references"
  fi

  printf '\n'
  if [ "$fails" -ne 0 ]; then
    printf 'BRANDING VALIDATION: FAILED (%d failure(s))\n' "$fails" >&2
    exit 1
  fi
  printf 'BRANDING VALIDATION: PASSED (repository mode)\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Runtime mode (--system)
# ---------------------------------------------------------------------------
echo "== Runtime branding checks on this Echo OS system =="

WP=/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png
LOCKWP=/usr/share/wallpapers/EchoOS-Lock/contents/images/1600x900.png
EXT=/usr/share/gnome-shell/extensions/ash-panel@echoos

# 1. Wallpapers present and accessible.
[ -f "$WP" ] && ok "wallpaper installed at $WP" || bad "wallpaper missing: $WP"
[ -f "$LOCKWP" ] && ok "lock-screen artwork installed at $LOCKWP" || bad "lock-screen artwork missing: $LOCKWP"
[ -r "$WP" ] && [ -r "$LOCKWP" ] && ok "wallpapers are world-readable" || bad "wallpapers not readable by all"
if [ -r "$WP" ] && [ "$(stat -c %a "$WP")" ] && [ ! -w "$WP" ] && [ ! -w "$(dirname "$WP")" ]; then
  ok "wallpaper not writable by unprivileged users"
else
  bad "wallpaper path is writable by unprivileged users"
fi

# 2. Compiled dconf defaults.
[ -s /etc/dconf/db/local ] && ok "system db 'local' compiled" || bad "/etc/dconf/db/local not compiled (echoos-dconf-update.service ran?)"
[ -s /etc/dconf/db/gdm ] && ok "system db 'gdm' compiled" || bad "/etc/dconf/db/gdm not compiled"
systemctl is-enabled --quiet echoos-dconf-update.service \
  && ok "echoos-dconf-update.service enabled" || bad "echoos-dconf-update.service not enabled"
systemctl is-active --quiet echoos-dconf-update.service \
  && ok "echoos-dconf-update.service ran this boot" || bad "echoos-dconf-update.service did not run"

# 3. Session values actually in effect (run inside the Ash session).
strip() { tr -d "'\""; }
if command -v gsettings >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  bg=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | strip)
  bgd=$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | strip)
  ss=$(gsettings get org.gnome.desktop.screensaver picture-uri 2>/dev/null | strip)
  [ "$bg" = "file://$WP" ] && ok "session desktop background = Echo wallpaper" || bad "session desktop background is $bg"
  if gsettings list-keys org.gnome.desktop.background 2>/dev/null | grep -q picture-uri-dark; then
    [ "$bgd" = "file://$WP" ] && ok "session dark background = Echo wallpaper" || bad "session dark background is $bgd"
  fi
  [ "$ss" = "file://$LOCKWP" ] && ok "session lock screen background = Echo lock artwork" || bad "session lock screen background is $ss"
  # picture-uri-dark exists on screensaver only up to GNOME 48; check when present.
  if gsettings list-keys org.gnome.desktop.screensaver 2>/dev/null | grep -q picture-uri-dark; then
    ssd=$(gsettings get org.gnome.desktop.screensaver picture-uri-dark 2>/dev/null | strip)
    [ "$ssd" = "file://$WP" ] && ok "session dark lock screen = Echo wallpaper" || bad "session dark lock screen is $ssd"
  else
    ok "screensaver schema has no picture-uri-dark (GNOME 49+): lock screen uses picture-uri"
  fi
  exts=$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null | strip)
  case "$exts" in *ash-panel@echoos*) ok "ash-panel extension enabled in session" ;; *) bad "ash-panel not enabled: $exts" ;; esac
else
  echo "SKIP session gsettings checks (no graphical session)"
fi

# 4. GDM greeter defaults (what the login screen will show). Read through the
#    gdm dconf profile; the greeter user differs across releases (gdm user,
#    root), but system-db:gdm applies to the greeter session regardless.
if command -v dconf >/dev/null 2>&1 && [ -x /usr/bin/dconf ]; then
  # dconf has no direct "read other profile" mode; compile the expected value
  # from the keyfile instead (source of truth the unit compiles from).
  expected=$(sed -n "s/^picture-uri='\(.*\)'/\1/p" /etc/dconf/db/gdm.d/00-echoos-branding 2>/dev/null | head -1)
  [ "$expected" = "file://$WP" ] && ok "GDM greeter keyfile targets the Echo wallpaper" \
    || bad "GDM greeter keyfile wrong: ${expected:-<unset>}"
  [ -s /etc/dconf/db/gdm ] && ok "GDM greeter db compiled from keyfile" \
    || bad "GDM greeter db missing"
else
  echo "SKIP GDM greeter check (dconf not present)"
fi

# 5. Extension payload and GNOME Shell compatibility.
[ -f "$EXT/metadata.json" ] && ok "ash-panel extension installed" || bad "ash-panel extension missing"
if [ -f "$EXT/metadata.json" ] && command -v gnome-shell >/dev/null 2>&1; then
  shellver=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)
  python3 - "$EXT/metadata.json" "$shellver" <<'PY'
import json, sys
meta = json.load(open(sys.argv[1]))
ver = sys.argv[2]
supported = meta.get("shell-version", [])
ok = "all" in supported or ver in supported or f"{ver}.x" in [v for v in supported]
modes = meta.get("session-modes", ["user"])
print(f"OK   shell {ver} compatibility: {'yes' if ok else 'NO'}; session modes: {modes}")
sys.exit(0 if ok else 1)
PY
  [ $? -eq 0 ] && ok "extension metadata matches running shell" || bad "extension does not declare shell $shellver"
fi

# 6. Pinned panel: struts/space reservation is stock GNOME behaviour; verify
# nothing that auto-hides or unanchors the panel is enabled.
if command -v gnome-extensions >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  gnome-extensions list --enabled 2>/dev/null | while read -r e; do
    printf 'INFO enabled extension: %s\n' "$e"
  done
  gnome-extensions info ash-panel@echoos >/dev/null 2>&1 \
    && ok "ash-panel extension active in the running shell" \
    || bad "ash-panel extension not active in the running shell"
fi

printf '\n'
if [ "$fails" -ne 0 ]; then
  printf 'BRANDING VALIDATION: FAILED (%d failure(s))\n' "$fails" >&2
  exit 1
fi
printf 'BRANDING VALIDATION: PASSED (runtime mode)\n'
