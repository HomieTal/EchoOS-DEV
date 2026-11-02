#!/usr/bin/env bash
# MAD Installer component validation.
#
# Complements build/validate.sh with checks specific to the MAD identity.
# Read-only against the component tree. Run from anywhere.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMP="$HERE"
fail=0
ok()   { printf 'OK   %s\n' "$1"; }
bad()  { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

# 1. Branding integrity
grep -Eq '^branding:[[:space:]]*mad$' "$COMP/calamares/settings.conf" \
  || bad "settings.conf does not select branding: mad"
grep -Eq '^componentName:[[:space:]]*mad$' "$COMP/calamares/branding/mad/branding.desc" \
  || bad "branding.desc componentName is not mad"
for img in productIcon.png productLogo-light.png productWelcome.png slideshow.qml stylesheet.qss; do
  [[ -s "$COMP/calamares/branding/mad/$img" ]] || bad "branding/mad missing $img"
done
img_refs=$(grep -hoE '"(product|echo)[^"]*\.(png|svg)"' "$COMP/calamares/branding/mad/branding.desc" "$COMP/calamares/branding/mad/slideshow.qml" 2>/dev/null | tr -d '"' | sort -u || true)
# -h strips filenames so each hit is a bare asset name relative to branding/mad/
for ref in $img_refs; do
  [[ -s "$COMP/calamares/branding/mad/$ref" ]] || bad "branding references missing asset: $ref"
done
if ls "$COMP/calamares/branding/mad"/{banner,squid,languages}*.png >/dev/null 2>&1; then
  bad "upstream Calamares artwork must not ship in branding/mad"
else
  ok "no upstream Calamares artwork in branding/mad"
fi
grep -q 'Master logo, verbatim copy\|verbatim' "$COMP/calamares/branding/mad/branding.desc" 2>/dev/null \
  && ok "branding.desc documents the master-logo derivation" \
  || true
[[ -s "$COMP/calamares/branding/mad/echo-mark.svg" ]] || bad "master echo-mark.svg missing from branding/mad"

# 2. Identity sweep — no stale Echo Install file identities (OS-level
#    'echoos' strings are intentionally retained; see README branding rules).
#    scripts/ is excluded: this validator's own pattern strings would match.
if grep -rn "echoos-install-launcher\|echoos-calamares\|echoos-refindconf-write\|echoos-refind-sync" \
      "$COMP" --include='*.conf' --include='*.desktop' --include='*.hook' \
      --include='*.rules' --exclude-dir=scripts --exclude-dir=docs 2>/dev/null | grep -v '^Binary'; then
  bad "stale Echo Install script identities found"
else
  ok "no stale Echo Install script identities"
fi

# 3. Desktop integration
for entry in "$COMP/config/home/archiso/Desktop/mad-installer.desktop" \
             "$COMP/config/live/xdg/autostart/mad-installer.desktop"; do
  grep -q '^Name=MAD Installer' "$entry" || bad "$(basename "$entry"): Name is not 'MAD Installer'"
  grep -q '^Icon=mad-installer' "$entry" || bad "$(basename "$entry"): Icon is not mad-installer"
  grep -q '^Exec=/usr/local/bin/mad-installer-launcher' "$entry" || bad "$(basename "$entry"): Exec is not the MAD launcher"
done
[[ -s "$COMP/config/rootfs/usr/share/icons/hicolor/64x64/apps/mad-installer.png" ]] \
  || bad "hicolor icon mad-installer.png missing"
ok "desktop entries reference the MAD launcher/icon"

# 4. Exclude-list consistency: every MAD live-only file the component ships
#    must be stripped from the installed target.
for f in /etc/xdg/autostart/mad-installer.desktop \
         /usr/local/bin/mad-installer-launcher \
         /usr/local/bin/mad-installer-x11; do
  grep -Fxq "$f" "$COMP/calamares/modules/unpackfs/exclude-list.txt" \
    || bad "exclude-list.txt does not exclude $f"
done
ok "exclude list strips MAD live-only files"

# 5. Launch path
grep -q 'exec pkexec /usr/bin/calamares' "$COMP/config/rootfs/usr/local/bin/mad-installer-launcher" \
  || bad "launcher does not escalate via pkexec to /usr/bin/calamares"
[[ -x "$COMP/config/rootfs/usr/local/bin/mad-installer-launcher" ]] \
  || bad "launcher is not executable"
[[ -x "$COMP/config/rootfs/usr/local/sbin/mad-refindconf-write" ]] \
  || bad "mad-refindconf-write is not executable"

# 6. QML syntax (Calamares imports will warn outside the runtime — tolerated)
if command -v qmllint >/dev/null 2>&1 || [ -x /usr/lib/qt6/bin/qmllint ]; then
  LINT="$(command -v qmllint || echo /usr/lib/qt6/bin/qmllint)"
  if "$LINT" "$COMP/calamares/branding/mad/slideshow.qml" >/dev/null 2>&1; then
    ok "slideshow.qml passes qmllint"
  else
    bad "slideshow.qml fails qmllint"
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "MAD INSTALLER COMPONENT VALIDATION: PASSED"
else
  echo "MAD INSTALLER COMPONENT VALIDATION: $fail failure(s)"
  exit 1
fi
