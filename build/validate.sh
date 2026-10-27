#!/usr/bin/env bash
# Echo OS build validation.
#
# Validates the component model and the *assembled* profile. It does not use
# profile/ (the legacy XFCE/LightDM reference) for parity, because the build
# input is now build/generated/profile.
#
# Read-only with respect to the repository; mkarchiso is never run.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fails=0
ok()  { printf 'OK   %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*" >&2; fails=$((fails + 1)); }

check_file() {
    [[ -s "$1" ]] && ok "file $1" || bad "missing or empty file $1"
}

check_grep() {
    local pattern=$1 file=$2 label=$3
    grep -qE "$pattern" "$file" && ok "$label" || bad "$label ($file)"
}

# ---------------------------------------------------------------------------
# 1. Component structure
# ---------------------------------------------------------------------------
components=(echo-core echo-boot echo-desktop echo-install)
for c in "${components[@]}"; do
    check_file "components/$c/README.md"
    check_file "components/$c/packages/packages.x86_64"
    check_file "components/$c/packages/packages.aarch64"
done

check_file build/config/components.tsv
check_file build/config/overlays.tsv
check_file build/template/profiledef.sh
check_file build/template/bootstrap_packages
check_file build/config/pacman.conf.in
check_file scripts/refind-iso.sh
check_file build.sh

# Required assembly order: Desktop after Core, before Installer.
if awk -F'\t' 'NR>1 && $2=="echo-desktop" {d=$1} NR>1 && $2=="echo-install" {i=$1} END {exit !(d+0 > 10 && d+0 < i+0)}' \
        build/config/components.tsv; then
    ok "echo-desktop ordered between echo-core and echo-install"
else
    bad "echo-desktop order in components.tsv is wrong"
fi

# Overlay sources must exist. Per-file destination collisions are hard errors
# inside build/assemble.sh (it aborts), so a successful assembly run below
# also proves there are no duplicate file destinations.
while IFS=$'\t' read -r _comp src _dst; do
    [[ "$_comp" == "component" ]] && continue
    [[ -d "components/$_comp/$src" ]] || bad "overlay source missing: components/$_comp/$src"
done < build/config/overlays.tsv
ok "overlay sources checked"

# Package uniqueness per architecture across all component manifests.
for arch in x86_64 aarch64; do
    dups="$(for c in "${components[@]}"; do
                sed -e 's/#.*//' -e 's/[[:space:]]//g' "components/$c/packages/packages.$arch"
            done | grep -v '^$' | sort | uniq -d)"
    [[ -z "$dups" ]] && ok "no duplicate packages ($arch)" || bad "duplicate packages ($arch): $dups"
done

# Desktop-owned component self-check.
if components/echo-desktop/scripts/validate-desktop.sh >/tmp/echo-desktop-validate.log 2>&1; then
    ok "echo-desktop component validation"
else
    bad "echo-desktop component validation failed (see /tmp/echo-desktop-validate.log)"
    cat /tmp/echo-desktop-validate.log >&2
fi

# ---------------------------------------------------------------------------
# 2. Assembly
# ---------------------------------------------------------------------------
GEN="build/generated/validate-profile"
rm -rf "$GEN"
if build/assemble.sh --arch x86_64 --out "$GEN" >/tmp/echo-assemble.log 2>&1; then
    ok "assemble x86_64"
else
    bad "assemble x86_64 failed (see /tmp/echo-assemble.log)"
    cat /tmp/echo-assemble.log >&2
    echo "VALIDATION: FAILED ($fails)" >&2
    exit 1
fi
PKGS="$GEN/packages.x86_64"

# ---------------------------------------------------------------------------
# 3. Assembled profile: desktop
# ---------------------------------------------------------------------------
grep -qxE 'lightdm|lightdm-gtk-greeter|xfce4-.*|xfdesktop|xfwm4|thunar|exo|garcon|tumbler' "$PKGS" \
    && bad "legacy XFCE/LightDM packages still declared" || ok "no XFCE/LightDM packages"

for pkg in plasma-meta sddm pipewire wireplumber xdg-desktop-portal-kde xorg-xwayland; do
    grep -qx "$pkg" "$PKGS" && ok "package $pkg" || bad "required desktop package missing: $pkg"
done
for pkg in refind calamares linux; do
    grep -qx "$pkg" "$PKGS" && ok "package $pkg" || bad "required package missing: $pkg"
done

check_file "$GEN/airootfs/etc/sddm.conf"
check_file "$GEN/airootfs/etc/sddm.conf.d/10-echoos-live-autologin.conf"
check_grep '^User=archiso$' "$GEN/airootfs/etc/sddm.conf.d/10-echoos-live-autologin.conf" "SDDM live autologin user"
check_grep '^Session=plasma\.desktop$' "$GEN/airootfs/etc/sddm.conf.d/10-echoos-live-autologin.conf" "SDDM live session plasma.desktop"
# SDDM reads /etc/sddm.conf last; an [Autologin] section there would mask
# the live drop-in (and did during VM testing).
if grep -qE '^\[Autologin\]' "$GEN/airootfs/etc/sddm.conf"; then
    bad "/etc/sddm.conf contains [Autologin] and would override the live drop-in"
else
    ok "sddm.conf does not mask live autologin"
fi

link="$GEN/airootfs/etc/systemd/system/display-manager.service"
if [[ -L "$link" && "$(readlink "$link")" == "/usr/lib/systemd/system/sddm.service" ]]; then
    ok "display-manager.service -> sddm.service"
else
    bad "display-manager.service does not point at sddm.service"
fi

check_grep 'LookAndFeelPackage=org.echoos.desktop' "$GEN/airootfs/etc/xdg/kdeglobals" "system look-and-feel default"
check_file "$GEN/airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/metadata.json"
check_file "$GEN/airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/defaults"
check_file "$GEN/airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js"
check_grep '^Image=file:///usr/share/wallpapers/EchoOS$' \
    "$GEN/airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/defaults" \
    "look-and-feel wallpaper default"
check_grep "writeConfig\('Image', 'file:///usr/share/wallpapers/EchoOS'\)" \
    "$GEN/airootfs/usr/share/plasma/look-and-feel/org.echoos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
    "layout writes Echo OS wallpaper"
check_file "$GEN/airootfs/usr/share/wallpapers/EchoOS/contents/images/1920x1080.png"

# Live-only: keep Plasma's first-run Welcome Center from covering the
# autostarted installer.  /home/archiso is excluded from the target, so
# installed systems are unaffected.
check_file "$GEN/airootfs/home/archiso/.config/plasma-welcomerc"
check_grep '^LastSeenVersion=9999$' "$GEN/airootfs/home/archiso/.config/plasma-welcomerc" \
    "live Welcome Center suppressed"

if find "$GEN/airootfs" -iname '*lightdm*' -o -iname '*xfce*' | grep -q .; then
    bad "legacy LightDM/XFCE files present in assembled profile"
else
    ok "no legacy LightDM/XFCE files"
fi

# ---------------------------------------------------------------------------
# 4. Assembled profile: installer
# ---------------------------------------------------------------------------
CAL="$GEN/airootfs/etc/calamares"
check_grep 'shellprocess@refindboot' "$CAL/settings.conf" "Calamares installs rEFInd"
check_grep 'displaymanagers:' "$CAL/modules/displaymanager.conf" "Calamares displaymanager module present"
if awk '/^displaymanagers:/{f=1;next} f&&/^ *-/{print $2;exit}' "$CAL/modules/displaymanager.conf" | grep -qx sddm; then
    ok "Calamares displaymanager targets sddm"
else
    bad "Calamares displaymanager does not target sddm"
fi
check_grep 'sddm\.service' "$CAL/modules/services-systemd.conf" "Calamares enables sddm.service"
check_grep '^/etc/sddm\.conf\.d/$' "$CAL/modules/unpackfs/exclude-list.txt" "live SDDM drop-in excluded from target"
grep -q 'lightdm' "$CAL/modules/unpackfs/exclude-list.txt" && bad "exclude list still references lightdm" || ok "exclude list free of lightdm"
check_file "$CAL/modules/partition.conf"
check_file "$CAL/modules/shellprocess-refindboot.conf"

# Every shellprocess@ID in the sequence needs an instances: declaration with
# its config.  An undeclared instance falls back to the module's stock
# example config (shellprocess.conf), whose sample script runs
# /usr/local/bin/slowloris and aborts the install with exit 127; found in
# live install testing on 2026-10-26.
seq_ids="$(grep -o 'shellprocess@[A-Za-z0-9_-]*' "$CAL/settings.conf" | sed 's/.*@//' | sort -u)"
decl_ids="$(sed -n '/^instances:/,/^[^ #]/p' "$CAL/settings.conf" | sed -n 's/.*- id: *//p' | sort -u)"
missing=""
for id in $seq_ids; do
    grep -qx "$id" <<<"$decl_ids" || missing="$missing $id"
done
if [[ -n "$seq_ids" && -z "$missing" ]]; then
    ok "all shellprocess instances declared in settings.conf ($(echo $seq_ids | tr '\n' ' '))"
else
    bad "shellprocess instance(s) not declared in settings.conf instances:$missing"
fi

for f in "$GEN/airootfs/usr/local/bin/echoos-install-launcher" \
         "$GEN/airootfs/usr/local/bin/echoos-calamares"; do
    [[ -x "$f" ]] && ok "executable $f" || bad "missing or not executable: $f"
done

# mkarchiso sources profiledef.sh from inside _read_profile().  The array
# must therefore be declared global (-g); a plain `declare -A` would be
# function-local there, leaving mkarchiso's permissions loop empty and the
# scripts at mode 0644 despite being executable in the assembled profile.
perm_count="$(bash -c '
    declare -A file_permissions=()
    . "$1" >/dev/null 2>&1
    printf "%s" "${#file_permissions[@]}"
' _ "$GEN/profiledef.sh")"
if [[ "${perm_count:-0}" -gt 0 ]]; then
    ok "profiledef file_permissions visible to mkarchiso (${perm_count} entries)"
else
    bad "profiledef file_permissions is function-local; mkarchiso cannot apply modes"
fi
check_grep 'pkexec /usr/bin/env' "$GEN/airootfs/usr/local/bin/echoos-install-launcher" "launcher forwards environment through pkexec"
check_grep 'DISPLAY="\$DISPLAY"' "$GEN/airootfs/usr/local/bin/echoos-install-launcher" "launcher forwards DISPLAY"
check_grep 'XAUTHORITY="\$XAUTHORITY"' "$GEN/airootfs/usr/local/bin/echoos-install-launcher" "launcher forwards XAUTHORITY"
check_grep 'echoos-calamares' "$GEN/airootfs/usr/local/bin/echoos-install-launcher" "launcher uses XWayland wrapper"
check_file "$GEN/airootfs/etc/xdg/autostart/echoos-install.desktop"
check_file "$GEN/airootfs/home/archiso/Desktop/echoos-install.desktop"

# ---------------------------------------------------------------------------
# 5. Assembled profile: boot
# ---------------------------------------------------------------------------
check_file "$GEN/EFI/BOOT/BOOTx64.EFI"
check_file "$GEN/EFI/BOOT/refind.conf"
check_file "$GEN/efiboot/loader/loader.conf"
check_file "$GEN/grub/grub.cfg"
check_file "$GEN/syslinux/syslinux.cfg"
check_file "$GEN/airootfs/etc/mkinitcpio.conf.d/archiso.conf"

# Every file_permissions path in the assembled profiledef must exist, except
# for paths mkarchiso creates itself (/etc/shadow, /etc/gshadow, /root, ...).
missing_perm=0
while IFS= read -r path; do
    case "$path" in
        /etc/shadow|/etc/gshadow|/etc/group|/root|/root/.gnupg) continue ;;
    esac
    [[ -e "$GEN/airootfs$path" ]] || { bad "file_permissions path missing: $path"; missing_perm=1; }
done < <(sed -n 's/^ *\["\([^"]*\)"\]=.*/\1/p' "$GEN/profiledef.sh")
(( missing_perm == 0 )) && ok "file_permissions paths exist"

rm -rf "$GEN"

if [[ $fails -eq 0 ]]; then
    echo "ECHO BUILD VALIDATION: PASSED"
    exit 0
fi
echo "ECHO BUILD VALIDATION: FAILED ($fails)" >&2
exit 1
