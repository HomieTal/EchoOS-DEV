#!/usr/bin/env bash
# Echo OS validation.
#
# Checks the four-component model, package ownership, the assembled profile,
# the GNOME/GDM desktop contract, and the live/target boundary.
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
  components/ash-desktop/packages
  components/ash-desktop/config/airootfs
  components/ash-desktop/config/live
  components/mad-install/packages
  components/mad-install/calamares
  components/mad-install/config
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
  components/ash-desktop/README.md
  components/ash-desktop/packages/packages.x86_64
  components/ash-desktop/packages/packages.aarch64
  components/mad-install/README.md
  components/mad-install/packages/packages.x86_64
  components/mad-install/packages/packages.aarch64
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

for c in echo-core echo-boot ash-desktop mad-install; do
  [[ -n "${order_of[$c]:-}" ]] || bad "component missing from components.tsv: $c"
done
[[ "${order_of[echo-core]:-0}" -lt "${order_of[ash-desktop]:-0}" ]] || bad "ash-desktop must come after echo-core"
[[ "${order_of[echo-boot]:-0}" -lt "${order_of[mad-install]:-0}" ]] || bad "mad-install must come after echo-boot"
[[ "${order_of[ash-desktop]:-0}" -lt "${order_of[mad-install]:-0}" ]] || bad "mad-install must come after ash-desktop"

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
  for c in echo-core echo-boot ash-desktop mad-install; do
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

# Desktop must own the GNOME/GDM stack; Core/Installer/Boot must not.
for arch in x86_64 aarch64; do
  for p in gnome gdm; do
    grep -Fxq "$p" "$TMPDIR/ash-desktop.$arch" || bad "ash-desktop/$arch is missing $p"
  done
  for c in echo-core echo-boot mad-install; do
    for p in plasma-meta sddm gnome gdm xfce4 lightdm lightdm-gtk-greeter; do
      if grep -Fxq "$p" "$TMPDIR/$c.$arch" 2>/dev/null; then
        bad "$c/$arch must not declare desktop package $p"
      fi
    done
  done
done

obsolete='^(plasma-meta|sddm|sddm-kcm|kwin|konsole|dolphin|qt6-wayland|xfce4|xfce4-goodies|lightdm|lightdm-gtk-greeter|lightdm-gtk-greeter-settings)$'
if grep -REh "$obsolete" components/*/packages/packages.x86_64 components/*/packages/packages.aarch64 2>/dev/null | grep -q .; then
  bad "obsolete XFCE/KDE/SDDM/LightDM package remains in a manifest"
else
  ok "no XFCE/KDE/SDDM/LightDM packages remain in component manifests"
fi

# ---------------------------------------------------------------------------
# Desktop configuration contract
# ---------------------------------------------------------------------------
d=components/ash-desktop/config
gdm_live="$d/live/etc/gdm/custom.conf"
accounts_live="$d/live/var/lib/AccountsService/users/archiso"
ash_session="$d/airootfs/usr/share/wayland-sessions/ash.desktop"
wallpaper_apply="$d/airootfs/usr/local/bin/echoos-wallpaper-apply"
wallpaper_autostart="$d/airootfs/etc/xdg/autostart/echoos-wallpaper.desktop"
wallpaper="$d/airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png"
mark="$d/airootfs/usr/share/echoos/echo-mark.png"

# GDM configuration is live-only: the installed target uses the GDM
# defaults (normal login screen) after the unpackfs exclusion.
[[ -s "$gdm_live" ]] || bad "missing live GDM autologin configuration"
grep -Eq '^AutomaticLoginEnable=true$' "$gdm_live" 2>/dev/null || bad "live GDM autologin is not enabled"
grep -Eq '^AutomaticLogin=archiso$' "$gdm_live" 2>/dev/null || bad "live GDM autologin user is not archiso"
[[ -s "$accounts_live" ]] || bad "missing live AccountsService session record"
grep -Eq '^Session=ash$' "$accounts_live" 2>/dev/null || bad "live AccountsService session is not ash"
grep -Eq '^Name=Ash Desktop$' "$ash_session" 2>/dev/null || bad "session is not registered as 'Ash Desktop'"
grep -Eq '^Exec=gnome-session$' "$ash_session" 2>/dev/null || bad "Ash Desktop session does not start gnome-session"
grep -Eq '^DesktopNames=GNOME;Ash$' "$ash_session" 2>/dev/null || bad "Ash Desktop session does not declare GNOME;Ash desktop names"
[[ -s "$wallpaper_apply" ]] || bad "missing wallpaper apply script"
grep -Eq 'gsettings set org\.gnome\.desktop\.background picture-uri' "$wallpaper_apply" 2>/dev/null \
  || bad "wallpaper apply script does not set the GNOME background"
grep -Fq '/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png' "$wallpaper_apply" 2>/dev/null \
  || bad "wallpaper apply script does not reference the Echo wallpaper"
grep -Eq '^OnlyShowIn=GNOME;Ash;$' "$wallpaper_autostart" 2>/dev/null || bad "wallpaper autostart is not restricted to GNOME/Ash"
[[ -s "$wallpaper" ]] || bad "missing Echo wallpaper"
[[ -s "$mark" ]] || bad "missing Echo mark"

dm_link="$d/live/etc/systemd/system/display-manager.service"
if [[ -L "$dm_link" ]]; then
  [[ "$(readlink "$dm_link")" == "/usr/lib/systemd/system/gdm.service" ]] \
    && ok "live display-manager link points at gdm" \
    || bad "live display-manager link does not point at gdm"
else
  bad "missing live display-manager link"
fi

# ---------------------------------------------------------------------------
# Installer contract
# ---------------------------------------------------------------------------
inst=components/mad-install/calamares
grep -Eq '^[[:space:]]*-[[:space:]]*gdm$' "$inst/modules/displaymanager.conf" || bad "Calamares displaymanager does not select GDM"
if grep -Eq '^[[:space:]]*-[[:space:]]*(sddm|lightdm)$' "$inst/modules/displaymanager.conf"; then bad "Calamares displaymanager still selects SDDM or LightDM"; fi
grep -Eq 'name: "gdm\.service"' "$inst/modules/services-systemd.conf" || bad "Calamares does not enable gdm.service"
if grep -Eq 'name: "(sddm|lightdm)\.service"' "$inst/modules/services-systemd.conf"; then bad "Calamares still enables sddm.service or lightdm.service"; fi
# The live GDM autologin is excluded from the target so the installed
# system shows the normal GDM login screen.
grep -Fq '/etc/gdm/custom.conf' "$inst/modules/unpackfs/exclude-list.txt" \
  || bad "live GDM autologin is not excluded from the target"
grep -Fq '/var/lib/AccountsService/users/archiso' "$inst/modules/unpackfs/exclude-list.txt" \
  || bad "live AccountsService session record is not excluded from the target"
grep -Fq '/etc/systemd/system/display-manager.service' "$inst/modules/unpackfs/exclude-list.txt" \
  || bad "live display-manager link is not excluded from the target"
grep -Eq '^branding:[[:space:]]*mad$' "$inst/settings.conf" || bad "Calamares branding is not mad"
grep -q 'id: refindboot' "$inst/settings.conf" || bad "Calamares refindboot instance is missing"
[[ -s components/mad-install/config/rootfs/usr/local/bin/mad-installer-launcher ]] || bad "installer launcher missing"
[[ -s components/mad-install/config/home/archiso/Desktop/mad-installer.desktop ]] || bad "installer desktop shortcut missing"
[[ -s components/mad-install/config/live/xdg/autostart/mad-installer.desktop ]] || bad "installer autostart missing"

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
             airootfs/etc/gdm/custom.conf \
             airootfs/etc/systemd/system/display-manager.service \
             airootfs/etc/calamares/modules/displaymanager.conf \
             airootfs/usr/share/wayland-sessions/ash.desktop \
             airootfs/var/lib/AccountsService/users/archiso \
             airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png; do
      [[ -e "$out/$f" || -L "$out/$f" ]] || bad "assembled profile is missing $f"
    done
    [[ -x "$out/airootfs/usr/local/bin/echoos-wallpaper-apply" ]] \
      || bad "assembled echoos-wallpaper-apply lost its executable bit"
    if grep -RElq 'sddm|lightdm|xfce4' "$out/airootfs/etc" 2>/dev/null; then
      bad "assembled profile still contains SDDM/LightDM/XFCE configuration"
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
    # MAD Installer migration: the old Echo Install branding component and
    # launcher file identities were replaced by MAD equivalents; the legacy
    # profile/ snapshot still carries the old paths.
    'airootfs/etc/polkit-1/rules.d/50-calamares.rules',
    'airootfs/etc/calamares/branding/echoos/banner.png',
    'airootfs/etc/calamares/branding/echoos/banner.png.license',
    'airootfs/etc/calamares/branding/echoos/branding.desc',
    'airootfs/etc/calamares/branding/echoos/echoos-logo.png',
    'airootfs/etc/calamares/branding/echoos/lang/calamares-default_ar.qm',
    'airootfs/etc/calamares/branding/echoos/lang/calamares-default_en.qm',
    'airootfs/etc/calamares/branding/echoos/lang/calamares-default_eo.qm',
    'airootfs/etc/calamares/branding/echoos/lang/calamares-default_fr.qm',
    'airootfs/etc/calamares/branding/echoos/lang/calamares-default_nl.qm',
    'airootfs/etc/calamares/branding/echoos/languages.png',
    'airootfs/etc/calamares/branding/echoos/languages.png.license',
    'airootfs/etc/calamares/branding/echoos/show.qml',
    'airootfs/etc/calamares/branding/echoos/squid.png',
    'airootfs/etc/calamares/branding/echoos/squid.png.license',
    'airootfs/etc/calamares/branding/echoos/stylesheet.qss',
    'airootfs/etc/xdg/autostart/echoos-install.desktop',
    'airootfs/home/archiso/Desktop/echoos-install.desktop',
    'airootfs/usr/local/bin/echoos-install-launcher',
    'airootfs/usr/local/sbin/echoos-refindconf-write',
    # MAD Installer: the Arch-branded syslinux BIOS boot path was removed
    # from the profile — the live medium boots via rEFInd (UEFI) only.
    'syslinux/archiso_head.cfg',
    'syslinux/archiso_pxe-linux.cfg',
    'syslinux/archiso_pxe.cfg',
    'syslinux/archiso_sys-linux.cfg',
    'syslinux/archiso_sys.cfg',
    'syslinux/archiso_tail.cfg',
    'syslinux/splash.png',
    'syslinux/syslinux.cfg',
    # GNOME migration: the legacy LightDM configuration files were replaced
    # by the GDM configuration of the ash-desktop component.
    'airootfs/etc/lightdm/lightdm.conf',
    'airootfs/etc/lightdm/lightdm.conf.d/20-autologin.conf',
}
expected_extra = {
    'airootfs/etc/calamares/branding/mad/branding.desc',
    'airootfs/etc/calamares/branding/mad/calamares-sidebar.qml',
    'airootfs/etc/calamares/branding/mad/echo-mark-light.svg',
    'airootfs/etc/calamares/branding/mad/echo-mark.svg',
    'airootfs/etc/calamares/branding/mad/finishedq.qml',
    'airootfs/etc/calamares/branding/mad/mad-mark.png',
    'airootfs/etc/calamares/branding/mad/productIcon.png',
    'airootfs/etc/calamares/branding/mad/productLogo-large.png',
    'airootfs/etc/calamares/branding/mad/productLogo-light.png',
    'airootfs/etc/calamares/branding/mad/productLogo.png',
    'airootfs/etc/calamares/branding/mad/productWelcome-light-bg.png',
    'airootfs/etc/calamares/branding/mad/productWelcome.png',
    'airootfs/etc/calamares/branding/mad/slideshow.qml',
    'airootfs/etc/calamares/branding/mad/stylesheet.qss',
    'airootfs/etc/calamares/branding/mad/welcomeq.qml',
    'airootfs/etc/calamares/modules/contextualprocess-madkeyboard.conf',
    'airootfs/etc/calamares/modules/finishedq.conf',
    'airootfs/etc/calamares/modules/welcomeq.conf',
    'airootfs/etc/gdm/custom.conf',
    'airootfs/usr/share/wayland-sessions/ash.desktop',
    'airootfs/var/lib/AccountsService/users/archiso',
    'airootfs/etc/pacman.d/hooks/echoos-os-release.hook',
    'airootfs/etc/polkit-1/rules.d/50-mad-installer.rules',
    'airootfs/etc/xdg/autostart/mad-installer.desktop',
    'airootfs/home/archiso/Desktop/mad-installer.desktop',
    'airootfs/etc/xdg/autostart/echoos-wallpaper.desktop',
    'airootfs/usr/local/bin/echoos-wallpaper-apply',
    'airootfs/usr/local/bin/mad-installer-launcher',
    'airootfs/usr/local/bin/mad-installer-x11',
    'airootfs/usr/local/sbin/mad-refindconf-write',
    'airootfs/usr/share/echoos/echo-mark.png',
    'airootfs/usr/share/echoos/os-release',
    'airootfs/usr/share/icons/hicolor/64x64/apps/mad-installer.png',
    'airootfs/usr/share/libalpm/hooks/mad-refind-sync.hook',
    'airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png',
    'airootfs/usr/share/wallpapers/EchoOS/metadata.json',
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
for p in /etc/gdm/custom.conf /usr/share/echoos/echo-mark.png \
         /usr/local/sbin/mad-refindconf-write /home/archiso/Desktop/mad-installer.desktop; do
  grep -Fq "[\"$p\"]" "$pd" || bad "profiledef.sh has no permission entry for $p"
done
if grep -Eq '/etc/(sddm|lightdm)|xfce4' "$pd"; then bad "profiledef.sh still has SDDM/LightDM/XFCE permission entries"; fi
if grep -Fq "bios.syslinux" "$pd"; then bad "profiledef.sh still has the Arch syslinux BIOS bootmode"; fi
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
printf 'Desktop: Ash Desktop / GDM (GNOME technology base)\n'
printf 'No ISO built; boot/install verification is a separate step.\n'
exit 0
