#!/usr/bin/env bash
# Echo OS validation.
#
# Checks the four-component model, package ownership, the assembled profile,
# the KDE Plasma/SDDM desktop contract, and the live/target boundary.
# Read-only with respect to profile/, components/, and build/generated/:
# assembly is performed in a temporary directory.
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMPBASE="${TMPDIR:-/tmp/opencode}"
mkdir -p "$TMPBASE"
TMPDIR="$(mktemp -d "${TMPBASE}/echo-validate.XXXXXX")"
trap 'rm -rf "$TMPDIR"' EXIT

failures=0
ok() { printf 'OK   %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*" >&2; failures=$((failures + 1)); }
info() { printf 'INFO %s\n' "$*"; }

components_map=build/config/components.tsv
overlays_map=build/config/overlays.tsv

# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------
required_dirs=(
  components/echo-core/packages
  components/echo-core/airootfs
  components/echo-core/live
  components/echo-boot/packages
  components/echo-boot/config
  components/echo-desktop/packages
  components/echo-desktop/config/airootfs
  components/echo-desktop/config/live
  components/echo-install/packages
  components/echo-install/calamares
  components/echo-install/config
  build/config
  build/template
)
for d in "${required_dirs[@]}"; do
  if [[ -d "$d" ]]; then ok "directory $d"; else bad "missing directory $d"; fi
done

required_files=(
  components/README.md
  components/echo-core/README.md
  components/echo-core/packages/packages.x86_64
  components/echo-core/packages/packages.aarch64
  components/echo-boot/README.md
  components/echo-boot/packages/packages.x86_64
  components/echo-boot/packages/packages.aarch64
  components/echo-desktop/README.md
  components/echo-desktop/packages/packages.x86_64
  components/echo-desktop/packages/packages.aarch64
  components/echo-install/README.md
  components/echo-install/packages/packages.x86_64
  components/echo-install/packages/packages.aarch64
  build/assemble.sh
  build/validate.sh
  build/config/components.tsv
  build/config/overlays.tsv
  build/config/pacman.conf.in
  build/template/profiledef.sh
  build/template/bootstrap_packages
)
for f in "${required_files[@]}"; do
  if [[ -s "$f" ]]; then ok "file $f"; else bad "missing or empty file $f"; fi
done

check_header() {
  local file=$1 expected=$2 actual
  actual="$(head -n 1 "$file" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then ok "header $file"; else bad "unexpected header in $file"; fi
}
check_header "$components_map" $'order\tcomponent\troot\trequires'
check_header "$overlays_map" $'component\tsource_prefix\tdestination_prefix'

# ---------------------------------------------------------------------------
# Component order and dependencies
# ---------------------------------------------------------------------------
declare -A order_of=() seen_order=()
last=0
while IFS=$'\t' read -r order component root requires; do
  [[ "$order" == "order" ]] && continue
  if [[ ! "$order" =~ ^[0-9]+$ ]]; then bad "invalid component order $order"; continue; fi
  if [[ -n "${seen_order[$order]:-}" ]]; then bad "duplicate component order $order"; fi
  seen_order[$order]=1
  order_of[$component]=$order
  if [[ "$order" -lt "$last" ]]; then bad "component order not ascending at $component"; fi
  last=$order
  if [[ -d "$root" && -s "$root/README.md" ]]; then ok "component $component root and README"; else bad "component $component has no root/README"; fi
  for a in x86_64 aarch64; do
    [[ -f "$root/packages/packages.$a" ]] || bad "component $component has no packages.$a"
  done
done < "$components_map"

for c in echo-core echo-boot echo-desktop echo-install; do
  [[ -n "${order_of[$c]:-}" ]] || bad "component missing from components.tsv: $c"
done
[[ "${order_of[echo-core]:-0}" -lt "${order_of[echo-desktop]:-0}" ]] || bad "echo-desktop must come after echo-core"
[[ "${order_of[echo-boot]:-0}" -lt "${order_of[echo-install]:-0}" ]] || bad "echo-install must come after echo-boot"
[[ "${order_of[echo-desktop]:-0}" -lt "${order_of[echo-install]:-0}" ]] || bad "echo-install must come after echo-desktop"

while IFS=$'\t' read -r order component root requires; do
  [[ "$order" == "order" ]] && continue
  [[ "$requires" == "-" || -z "$requires" ]] && continue
  IFS=',' read -ra reqs <<< "$requires"
  for req in "${reqs[@]}"; do
    [[ -n "${order_of[$req]:-}" ]] || bad "$component depends on unknown component $req"
    if [[ -n "${order_of[$req]:-}" && "${order_of[$req]}" -ge "${order_of[$component]}" ]]; then
      bad "$component dependency $req is not ordered before it"
    fi
  done
done < "$components_map"

# Overlay prefixes must exist.  Exact file overlays are allowed.
while IFS=$'\t' read -r component source_prefix destination_prefix; do
  [[ "$component" == "component" ]] && continue
  [[ -n "${order_of[$component]:-}" ]] || bad "overlay for unknown component $component"
  [[ -e "components/$component/$source_prefix" || -L "components/$component/$source_prefix" ]] \
    || bad "overlay source missing: components/$component/$source_prefix"
  case "$destination_prefix" in
    ""|/*|..|../*|*/..|*/../*) bad "unsafe overlay destination: $destination_prefix" ;;
  esac
done < "$overlays_map"

# ---------------------------------------------------------------------------
# Package manifests
# ---------------------------------------------------------------------------
manifest_dupes=0
for arch in x86_64 aarch64; do
  : > "$TMPDIR/all_$arch"
  for c in echo-core echo-boot echo-desktop echo-install; do
    m="components/$c/packages/packages.$arch"
    [[ -f "$m" ]] || { bad "missing manifest $m"; continue; }
    grep -vE '^[[:space:]]*(#|$)' "$m" | sed 's/[[:space:]]//g' > "$TMPDIR/$c.$arch"
    if grep -vE '^[A-Za-z0-9@._+-]+$' "$TMPDIR/$c.$arch" | grep -q .; then
      bad "invalid package name in $m"
    fi
    if [[ -s "$TMPDIR/$c.$arch" ]] && ! LC_ALL=C sort -c "$TMPDIR/$c.$arch" 2>/dev/null; then
      bad "manifest not sorted: $m"
    fi
    if [[ -s "$TMPDIR/$c.$arch" ]] && [[ "$(uniq -d "$TMPDIR/$c.$arch" | wc -l)" -gt 0 ]]; then
      bad "duplicate package inside $m"
    fi
    cat "$TMPDIR/$c.$arch" >> "$TMPDIR/all_$arch"
  done
  LC_ALL=C sort "$TMPDIR/all_$arch" -o "$TMPDIR/all_$arch"
  if [[ -s "$TMPDIR/all_$arch" ]] && [[ "$(uniq -d "$TMPDIR/all_$arch" | wc -l)" -gt 0 ]]; then
    bad "duplicate packages across component manifests for $arch"
    uniq -d "$TMPDIR/all_$arch" >&2
    manifest_dupes=$((manifest_dupes + 1))
  fi
done
[[ "$manifest_dupes" -eq 0 ]] && ok "no duplicate packages across component manifests"

# Desktop must own the KDE/SDDM stack; Core/Installer/Boot must not.
for arch in x86_64 aarch64; do
  for p in plasma-meta sddm; do
    grep -Fxq "$p" "$TMPDIR/echo-desktop.$arch" || bad "echo-desktop/$arch is missing $p"
  done
  for c in echo-core echo-boot echo-install; do
    for p in plasma-meta sddm lightdm lightdm-gtk-greeter; do
      if grep -Fxq "$p" "$TMPDIR/$c.$arch" 2>/dev/null; then
        bad "$c/$arch must not declare desktop package $p"
      fi
    done
  done
done

obsolete='^(exo|garcon|lightdm|lightdm-gtk-greeter|polkit-gnome|thunar|thunar-volman|tumbler|xfce4-.*|xfdesktop|xfwm4)$'
if grep -REh "$obsolete" components/*/packages/packages.x86_64 components/*/packages/packages.aarch64 2>/dev/null | grep -q .; then
  bad "obsolete XFCE/LightDM package remains in a manifest"
else
  ok "no XFCE/LightDM packages remain in component manifests"
fi

# ---------------------------------------------------------------------------
# Desktop configuration contract
# ---------------------------------------------------------------------------
d=components/echo-desktop/config
sddm_common="$d/airootfs/etc/sddm.conf"
sddm_live="$d/live/etc/sddm.conf.d/20-echoos-live-autologin.conf"
theme="$d/airootfs/usr/share/sddm/themes/echoos"
wallpaper="$d/airootfs/usr/share/wallpapers/EchoOS/contents/images/2560x1280.jpg"

[[ -s "$sddm_common" ]] || bad "missing SDDM common configuration"
grep -Eq '^DisplayServer=wayland$' "$sddm_common" 2>/dev/null || bad "SDDM is not configured for Wayland"
grep -Eq '^Current=echoos$' "$sddm_common" 2>/dev/null || bad "SDDM Echo theme is not selected"
[[ -s "$sddm_live" ]] || bad "missing live SDDM autologin drop-in"
grep -Eq '^User=archiso$' "$sddm_live" 2>/dev/null || bad "live SDDM autologin user is not archiso"
grep -Eq '^Session=plasma\.desktop$' "$sddm_live" 2>/dev/null || bad "live SDDM session is not plasma.desktop"
[[ -s "$theme/Main.qml" ]] || bad "missing SDDM Echo greeter QML"
[[ -s "$theme/theme.conf" ]] || bad "missing SDDM Echo theme.conf"
[[ -s "$theme/metadata.desktop" ]] || bad "missing SDDM Echo theme metadata.desktop"
grep -Eq '^QtVersion=6$' "$theme/metadata.desktop" 2>/dev/null \
  || bad "SDDM Echo theme must declare QtVersion=6 (the image has no Qt5 greeter libraries)"
grep -Eq '^MainScript=Main\.qml$' "$theme/metadata.desktop" 2>/dev/null \
  || bad "SDDM Echo theme metadata does not point at Main.qml"
[[ -s "$wallpaper" ]] || bad "missing Echo wallpaper"
[[ -x "$d/airootfs/usr/local/bin/echoos-desktop-branding" ]] || bad "desktop branding helper is not executable"
[[ -s "$d/airootfs/etc/xdg/autostart/echoos-plasma-branding.desktop" ]] || bad "missing desktop branding autostart"

dm_link="$d/live/etc/systemd/system/display-manager.service"
if [[ -L "$dm_link" ]]; then
  [[ "$(readlink "$dm_link")" == "/usr/lib/systemd/system/sddm.service" ]] \
    && ok "live display-manager link points at sddm" \
    || bad "live display-manager link does not point at sddm"
else
  bad "missing live display-manager link"
fi

# ---------------------------------------------------------------------------
# Installer contract
# ---------------------------------------------------------------------------
inst=components/echo-install/calamares
grep -Eq '^[[:space:]]*-[[:space:]]*sddm$' "$inst/modules/displaymanager.conf" || bad "Calamares displaymanager does not select SDDM"
if grep -Eq '^[[:space:]]*-[[:space:]]*lightdm$' "$inst/modules/displaymanager.conf"; then bad "Calamares displaymanager still selects LightDM"; fi
grep -Eq 'name: "sddm\.service"' "$inst/modules/services-systemd.conf" || bad "Calamares does not enable sddm.service"
if grep -Eq 'name: "lightdm\.service"' "$inst/modules/services-systemd.conf"; then bad "Calamares still enables lightdm.service"; fi
# The live SDDM autologin is excluded from the target either as the exact
# drop-in file or as the whole /etc/sddm.conf.d/ directory (the current
# exclude list removes the directory, which covers the file).
grep -Fq '/etc/sddm.conf.d/20-echoos-live-autologin.conf' "$inst/modules/unpackfs/exclude-list.txt" \
  || grep -Fq '/etc/sddm.conf.d/' "$inst/modules/unpackfs/exclude-list.txt" \
  || bad "live SDDM autologin is not excluded from the target"
grep -Fq '/etc/systemd/system/display-manager.service' "$inst/modules/unpackfs/exclude-list.txt" \
  || bad "live display-manager link is not excluded from the target"
grep -Eq '^branding:[[:space:]]*echoos$' "$inst/settings.conf" || bad "Calamares branding is not echoos"
grep -q 'id: refindboot' "$inst/settings.conf" || bad "Calamares refindboot instance is missing"
[[ -s components/echo-install/config/rootfs/usr/local/bin/echoos-install-launcher ]] || bad "installer launcher missing"
[[ -s components/echo-install/config/home/archiso/Desktop/echoos-install.desktop ]] || bad "installer desktop shortcut missing"
[[ -s components/echo-install/config/live/xdg/autostart/echoos-install.desktop ]] || bad "installer autostart missing"

# ---------------------------------------------------------------------------
# Assemble both architectures in isolation.
# ---------------------------------------------------------------------------
for arch in x86_64 aarch64; do
  out="$TMPDIR/profile-$arch"
  if ./build/assemble.sh --arch "$arch" --out "$out" >"$TMPDIR/assemble-$arch.log" 2>&1; then
    ok "assembly succeeds for $arch"
  else
    bad "assembly failed for $arch"
    sed -n '1,20p' "$TMPDIR/assemble-$arch.log" >&2
    continue
  fi
  [[ -s "$out/packages.$arch" ]] || bad "assembled $arch package list is empty"
  LC_ALL=C sort "$TMPDIR/all_$arch" > "$TMPDIR/expected-$arch"
  if cmp -s "$TMPDIR/expected-$arch" "$out/packages.$arch"; then
    ok "assembled $arch package list matches component manifests"
  else
    bad "assembled $arch package list differs from component manifests"
  fi
  if [[ "$arch" == "x86_64" ]]; then
    for f in profiledef.sh bootstrap_packages pacman.conf pacman.conf.in packages.x86_64 \
             airootfs/etc/sddm.conf \
             airootfs/etc/sddm.conf.d/20-echoos-live-autologin.conf \
             airootfs/etc/systemd/system/display-manager.service \
             airootfs/etc/calamares/modules/displaymanager.conf \
             airootfs/usr/share/sddm/themes/echoos/Main.qml \
             airootfs/usr/share/wallpapers/EchoOS/contents/images/2560x1280.jpg; do
      [[ -e "$out/$f" || -L "$out/$f" ]] || bad "assembled profile is missing $f"
    done
    if grep -RIlq 'lightdm' "$out/airootfs/etc" 2>/dev/null; then
      bad "assembled profile still contains LightDM configuration"
    fi
  fi
done

# The assembled tree must carry every legacy source path except the two
# LightDM files that Echo Desktop deliberately replaces, plus the desktop
# payload itself.
if [[ -d "$TMPDIR/profile-x86_64" ]]; then
  python3 - "$TMPDIR/profile-x86_64" > "$TMPDIR/path-diff" <<'PY'
import os, sys
out = sys.argv[1]
def files(root):
    return {os.path.relpath(os.path.join(d, f), root) for d, _, fs in os.walk(root) for f in fs}
legacy = files('profile')
built = files(out)
removed = {
    'airootfs/etc/lightdm/lightdm.conf',
    'airootfs/etc/lightdm/lightdm.conf.d/20-autologin.conf',
}
expected_extra = {
    'airootfs/etc/sddm.conf',
    'airootfs/etc/sddm.conf.d/20-echoos-live-autologin.conf',
    'airootfs/etc/xdg/autostart/echoos-plasma-branding.desktop',
    'airootfs/usr/local/bin/echoos-desktop-branding',
    'airootfs/usr/share/sddm/themes/echoos/Main.qml',
    'airootfs/usr/share/sddm/themes/echoos/background.jpg',
    'airootfs/usr/share/sddm/themes/echoos/logo.jpeg',
    'airootfs/usr/share/sddm/themes/echoos/metadata.desktop',
    'airootfs/usr/share/sddm/themes/echoos/theme.conf',
    'airootfs/usr/share/wallpapers/EchoOS/contents/images/2560x1280.jpg',
    'airootfs/usr/share/wallpapers/EchoOS/metadata.json',
    # Files that moved from the legacy profile tree into components during
    # the v3.0.0 migration (they live in echo-install and echo-boot now).
    'airootfs/etc/pacman.d/hooks/echoos-os-release.hook',
    'airootfs/usr/local/bin/echoos-calamares',
    'airootfs/usr/share/echoos/os-release',
    'airootfs/usr/share/libalpm/hooks/echoos-refind-sync.hook',
}
missing = sorted((legacy - removed) - built)
extra = sorted(built - legacy)
if missing:
    print('MISSING ' + ','.join(missing))
if extra != sorted(expected_extra):
    print('EXTRA ' + ','.join(extra))
PY
  if [[ -s "$TMPDIR/path-diff" ]]; then
    bad "assembled profile does not match the legacy tree plus the desktop payload"
    sed -n '1,20p' "$TMPDIR/path-diff" >&2
  else
    ok "assembled profile covers every legacy path and adds only Echo Desktop"
  fi
fi

# ---------------------------------------------------------------------------
# profiledef permissions
# ---------------------------------------------------------------------------
pd=build/template/profiledef.sh
for p in /etc/sddm.conf /etc/sddm.conf.d/20-echoos-live-autologin.conf \
         /usr/share/sddm/themes/echoos /usr/local/bin/echoos-desktop-branding \
         /usr/local/sbin/echoos-refindconf-write /home/archiso/Desktop/echoos-install.desktop; do
  grep -Fq "[\"$p\"]" "$pd" || bad "profiledef.sh has no permission entry for $p"
done
if grep -Fq '/etc/lightdm' "$pd"; then bad "profiledef.sh still has LightDM permission entries"; fi
grep -Fq "bootmodes=('bios.syslinux'" "$pd" || bad "profiledef.sh lost bios.syslinux bootmode"
grep -Fq "'uefi.systemd-boot'" "$pd" || bad "profiledef.sh lost uefi.systemd-boot bootmode"
grep -Fq 'pacman_conf="pacman.conf"' "$pd" || bad "profiledef.sh lost pacman_conf"

# ---------------------------------------------------------------------------
# packages/ host artifacts are still present
# ---------------------------------------------------------------------------
[[ -s packages/calamares-3.4.2-2-x86_64.pkg.tar.zst ]] || bad "Calamares package artifact missing from packages/"

printf '\n'
if [[ "$failures" -ne 0 ]]; then
  printf 'ECHO OS VALIDATION: FAILED (%d failure(s))\n' "$failures"
  exit 1
fi
printf 'ECHO OS VALIDATION: PASSED\n'
printf 'Components: Core -> Boot -> Desktop -> Installer\n'
printf 'Desktop: KDE Plasma 6 / KWin / SDDM Wayland\n'
printf 'No ISO built; boot/install verification is a separate step.\n'
exit 0
