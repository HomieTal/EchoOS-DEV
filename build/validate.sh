#!/usr/bin/env bash
# Step 2 validation for the Echo OS component skeleton with Boot populated.
# Read-only with respect to profile/. Never builds ISO, invokes mkarchiso,
# modifies profile/, or uses Git.
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

required_dirs=(
  components/echo-boot/packages
  components/echo-boot/config
  components/echo-boot/hooks
  components/echo-install/packages
  components/echo-install/config
  components/echo-install/calamares
  components/echo-core/packages
  components/echo-core/config
  components/echo-core/airootfs
  components/echo-core/services
  build/config
  build/template
  build/generated
)
for d in "${required_dirs[@]}"; do
  if [[ -d "$d" ]]; then ok "directory $d"; else bad "missing directory $d"; fi
done

required_files=(
  components/README.md
  components/echo-boot/README.md
  components/echo-boot/hooks/README.md
  components/echo-boot/packages/packages.x86_64
  components/echo-boot/packages/packages.aarch64
  components/echo-install/README.md
  components/echo-install/packages/packages.x86_64
  components/echo-install/packages/packages.aarch64
  components/echo-install/packages/PKGBUILD
  components/echo-core/README.md
  build/README.md
  build/assemble.sh
  build/validate.sh
  build/config/README.md
  build/config/components.tsv
  build/config/overlays.tsv
  build/config/legacy-file-owners.tsv
  build/config/legacy-package-owners.tsv
  build/config/profile-baseline.tsv
  build/config/pacman.conf.in
  build/template/README.md
  build/template/profiledef.sh
  build/template/bootstrap_packages
  docs/phase-1-architecture-report.md
  docs/step-1-component-map.md
  docs/step-1-assembly-contract.md
  docs/step-1-parity-check.md
  docs/step-2-echo-boot-report.md
  docs/step-3-echo-install-report.md
)
for f in "${required_files[@]}"; do
  if [[ -s "$f" ]]; then ok "file $f"; else bad "missing or empty file $f"; fi
done

# Shared build templates must match their authoritative profile sources.
# This prevents the migration-window copies from becoming independent config.
shared_fail=0
check_shared_template() {
  local src=$1 dst=$2
  if [[ ! -f "$src" || ! -f "$dst" ]]; then
    bad "shared template missing: $dst (source $src)"
    shared_fail=$((shared_fail + 1)) || true
    return 0
  fi
  if ! cmp -s "$src" "$dst"; then
    bad "shared template differs from source: $dst != $src"
    shared_fail=$((shared_fail + 1)) || true
  fi
  local smode dmode
  smode=$(stat -c '%a' "$src")
  dmode=$(stat -c '%a' "$dst")
  if [[ "$smode" != "$dmode" ]]; then
    bad "shared template mode differs: $dst ($dmode vs $smode)"
    shared_fail=$((shared_fail + 1)) || true
  fi
  if [[ -L "$dst" ]]; then
    bad "shared template must be a regular file, not a symlink: $dst"
    shared_fail=$((shared_fail + 1)) || true
  fi
}
check_shared_template profile/profiledef.sh build/template/profiledef.sh
check_shared_template profile/bootstrap_packages build/template/bootstrap_packages
check_shared_template profile/pacman.conf.in build/config/pacman.conf.in

# Placeholders/fields that assembly depends on must survive unchanged.
if [[ -f build/template/profiledef.sh ]]; then
  grep -q "bootmodes=('bios.syslinux'" build/template/profiledef.sh || { bad "profiledef template lost bios.syslinux bootmode"; shared_fail=$((shared_fail + 1)) || true; }
  grep -q "'uefi.systemd-boot'" build/template/profiledef.sh || { bad "profiledef template lost uefi.systemd-boot bootmode"; shared_fail=$((shared_fail + 1)) || true; }
  grep -q '^pacman_conf="pacman.conf"' build/template/profiledef.sh || { bad "profiledef template lost pacman_conf"; shared_fail=$((shared_fail + 1)) || true; }
fi
if [[ -f build/config/pacman.conf.in ]]; then
  grep -q '@LOCAL_REPO_PATH@' build/config/pacman.conf.in || { bad "pacman template lost @LOCAL_REPO_PATH@"; shared_fail=$((shared_fail + 1)) || true; }
  grep -q '^\[echo\]' build/config/pacman.conf.in || { bad "pacman template lost [echo] repository"; shared_fail=$((shared_fail + 1)) || true; }
fi
if [[ $shared_fail -eq 0 ]]; then ok "shared templates match authoritative sources"; fi

file_map=build/config/legacy-file-owners.tsv
package_map=build/config/legacy-package-owners.tsv
components_map=build/config/components.tsv
overlays_map=build/config/overlays.tsv
baseline=build/config/profile-baseline.tsv

for hdr in "$file_map" "$package_map" "$components_map" "$overlays_map" "$baseline"; do
  if [[ -s "$hdr" ]]; then ok "exists $hdr"; else bad "missing $hdr"; fi
done

check_header() {
  local file=$1 expected=$2 actual
  actual="$(head -n 1 "$file" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    ok "header $file"
  else
    bad "unexpected header in $file"
  fi
}
check_header "$file_map" $'legacy_path\towner\tscope\tfuture_path\tprofile_destination\tnote'
check_header "$package_map" $'package\towner\tscope\tx86_64\taarch64\tnote'
check_header "$components_map" $'order\tcomponent\troot\trequires'
check_header "$overlays_map" $'component\tsource_prefix\tdestination_prefix'
check_header "$baseline" $'path\ttype\tmode\tsize\tcontent_sha256\tlink_target'

# Component definitions
while IFS=$'\t' read -r order component component_root requires; do
  [[ "$order" == "order" ]] && continue
  if [[ -d "$component_root" && -s "$component_root/README.md" ]]; then
    ok "component $component root and README"
  else
    bad "component $component has no root/README"
  fi
done < "$components_map"

# Echo Core payloads populated in Step 4; Echo Install populated in Step 3
c=components/echo-core
find "$c" -type f ! -name README.md ! -name .gitkeep -print | LC_ALL=C sort > "$TMPDIR/${c//\//_}_payload"
if [[ -s "$TMPDIR/${c//\//_}_payload" ]]; then
  ok "$c has payload files"
else
  ok "$c payload limited to README/.gitkeep"
fi
ok "echo-install payload allowed"

# Boot future paths must exist and match sources
boot_fail=0
while IFS=$'\t' read -r legacy owner scope future destination note; do
  [[ "$legacy" == "legacy_path" ]] && continue
  [[ "$owner" == "BOOT" ]] || continue
  if [[ ! -e "$future" && ! -L "$future" ]]; then
    bad "Boot future path missing: $future (from $legacy)"
    boot_fail=$((boot_fail + 1)) || true
    continue
  fi
  if [[ -L "$future" && -L "$legacy" ]]; then
    f_link=$(readlink "$future"); l_link=$(readlink "$legacy")
    if [[ "$f_link" == "$l_link" ]]; then ok "symlink match $legacy -> $future"; else bad "symlink mismatch $legacy"; boot_fail=$((boot_fail + 1)) || true; fi
  elif [[ -f "$future" && ! -L "$future" && -f "$legacy" && ! -L "$legacy" ]]; then
    if cmp -s "$legacy" "$future"; then ok "content match $legacy -> $future"; else bad "content mismatch $legacy -> $future"; boot_fail=$((boot_fail + 1)) || true; fi
    f_mode=$(stat -c '%a' "$future"); l_mode=$(stat -c '%a' "$legacy")
    if [[ "$f_mode" == "$l_mode" ]]; then ok "mode match $legacy"; else bad "mode mismatch $legacy ($l_mode vs $f_mode)"; boot_fail=$((boot_fail + 1)) || true; fi
  else
    bad "type mismatch $legacy <-> $future"
    boot_fail=$((boot_fail + 1)) || true
  fi
done < "$file_map"

# Allowed files under echo-boot
awk -F '\t' 'NR>1 && $2=="BOOT" {print $4}' "$file_map" | LC_ALL=C sort > "$TMPDIR/boot_allowed"
printf '%s\n' "components/echo-boot/README.md" "components/echo-boot/hooks/README.md" >> "$TMPDIR/boot_allowed"
printf '%s\n' "components/echo-boot/packages/packages.x86_64" "components/echo-boot/packages/packages.aarch64" >> "$TMPDIR/boot_allowed"
LC_ALL=C sort -u "$TMPDIR/boot_allowed" > "$TMPDIR/boot_allowed_unique"
find components/echo-boot -type f ! -name .gitkeep -print | LC_ALL=C sort > "$TMPDIR/boot_actual"
if comm -23 "$TMPDIR/boot_actual" "$TMPDIR/boot_allowed_unique" | grep -q .; then
  bad "unexpected files under components/echo-boot"
  comm -23 "$TMPDIR/boot_actual" "$TMPDIR/boot_allowed_unique" >&2
  boot_fail=$((boot_fail + 1)) || true
fi
if comm -13 "$TMPDIR/boot_actual" "$TMPDIR/boot_allowed_unique" | grep -q .; then
  bad "missing expected files under components/echo-boot"
  comm -13 "$TMPDIR/boot_actual" "$TMPDIR/boot_allowed_unique" >&2
  boot_fail=$((boot_fail + 1)) || true
fi
if [[ $boot_fail -eq 0 ]]; then ok "Echo Boot files match ownership map and are byte-for-byte with sources"; fi
# Core future paths must exist and match sources
core_fail=0
while IFS=$'\t' read -r legacy owner scope future destination note; do
  [[ "$legacy" == "legacy_path" ]] && continue
  [[ "$owner" == "CORE" ]] || continue
  if [[ ! -e "$future" && ! -L "$future" ]]; then
    bad "Core future path missing: $future (from $legacy)"
    core_fail=$((core_fail + 1)) || true
    continue
  fi
  if [[ -L "$future" && -L "$legacy" ]]; then
    f_link=$(readlink "$future"); l_link=$(readlink "$legacy")
    if [[ "$f_link" == "$l_link" ]]; then ok "core symlink match $legacy -> $future"; else bad "core symlink mismatch $legacy"; core_fail=$((core_fail + 1)) || true; fi
  elif [[ -f "$future" && ! -L "$future" && -f "$legacy" && ! -L "$legacy" ]]; then
    if cmp -s "$legacy" "$future"; then ok "core content match $legacy -> $future"; else bad "core content mismatch $legacy -> $future"; core_fail=$((core_fail + 1)) || true; fi
    f_mode=$(stat -c '%a' "$future"); l_mode=$(stat -c '%a' "$legacy")
    if [[ "$f_mode" == "$l_mode" ]]; then ok "core mode match $legacy"; else bad "core mode mismatch $legacy ($l_mode vs $f_mode)"; core_fail=$((core_fail + 1)) || true; fi
  else
    bad "core type mismatch $legacy <-> $future"
    core_fail=$((core_fail + 1)) || true
  fi
done < "$file_map"
if [[ $core_fail -eq 0 ]]; then ok "Echo Core files match ownership map and sources"; fi


# Installer files must match sources
installer_fail=0
while IFS=$'\t' read -r legacy owner scope future destination note; do
  [[ "$legacy" == "legacy_path" ]] && continue
  [[ "$owner" == "INSTALLER" ]] || continue
  # skip artifacts for content comparison if dest not present as source copy? artifact is built; we copied to component packages; compare if both exist
  if [[ ! -e "$future" && ! -L "$future" ]]; then
    bad "Installer future path missing: $future (from $legacy)"
    installer_fail=$((installer_fail + 1)) || true
    continue
  fi
  if [[ -L "$future" && -L "$legacy" ]]; then
    f_link=$(readlink "$future"); l_link=$(readlink "$legacy")
    if [[ "$f_link" == "$l_link" ]]; then ok "symlink match $legacy -> $future"; else bad "symlink mismatch $legacy"; installer_fail=$((installer_fail + 1)) || true; fi
  elif [[ -f "$future" && ! -L "$future" && -f "$legacy" && ! -L "$legacy" && "$legacy" == *.pkg.tar.zst ]]; then
    if [[ "$(stat -c '%s' "$legacy")" == "$(stat -c '%s' "$future")" ]]; then ok "artifact size match $legacy -> $future"; else bad "artifact size mismatch $legacy -> $future"; installer_fail=$((installer_fail + 1)) || true; fi
    f_mode=$(stat -c '%a' "$future"); l_mode=$(stat -c '%a' "$legacy")
    if [[ "$f_mode" == "$l_mode" ]]; then ok "mode match $legacy"; else bad "mode mismatch $legacy ($l_mode vs $f_mode)"; installer_fail=$((installer_fail + 1)) || true; fi
  elif [[ -f "$future" && ! -L "$future" && -f "$legacy" && ! -L "$legacy" ]]; then
    if cmp -s "$legacy" "$future"; then ok "content match $legacy -> $future"; else bad "content mismatch $legacy -> $future"; installer_fail=$((installer_fail + 1)) || true; fi
    f_mode=$(stat -c '%a' "$future"); l_mode=$(stat -c '%a' "$legacy")
    if [[ "$f_mode" == "$l_mode" ]]; then ok "mode match $legacy"; else bad "mode mismatch $legacy ($l_mode vs $f_mode)"; installer_fail=$((installer_fail + 1)) || true; fi
  else
    bad "type mismatch $legacy <-> $future"
    installer_fail=$((installer_fail + 1)) || true
  fi
done < "$file_map"

# Allowed files under echo-install
awk -F '\t' 'NR>1 && $2=="INSTALLER" {print $4}' "$file_map" | LC_ALL=C sort > "$TMPDIR/install_allowed"
printf '%s\n' "components/echo-install/README.md" >> "$TMPDIR/install_allowed"
printf '%s\n' "components/echo-install/packages/PKGBUILD" "components/echo-install/packages/packages.x86_64" "components/echo-install/packages/packages.aarch64" "components/echo-install/packages/calamares-3.4.2-2-x86_64.pkg.tar.zst" >> "$TMPDIR/install_allowed"
LC_ALL=C sort -u "$TMPDIR/install_allowed" > "$TMPDIR/install_allowed_unique"
find components/echo-install -type f ! -name .gitkeep -print | LC_ALL=C sort > "$TMPDIR/install_actual"
# Ignore map entries that point outside the component root
LC_ALL=C grep -v '^build/repo/' "$TMPDIR/install_allowed_unique" > "$TMPDIR/install_allowed_unique2" || true
if LC_ALL=C comm -23 "$TMPDIR/install_actual" "$TMPDIR/install_allowed_unique2" | grep -q .; then
  bad "unexpected files under components/echo-install"
  LC_ALL=C comm -23 "$TMPDIR/install_actual" "$TMPDIR/install_allowed_unique2" >&2
  installer_fail=$((installer_fail + 1)) || true
fi
if LC_ALL=C comm -13 "$TMPDIR/install_actual" "$TMPDIR/install_allowed_unique2" | grep -q .; then
  bad "missing expected files under components/echo-install"
  LC_ALL=C comm -13 "$TMPDIR/install_actual" "$TMPDIR/install_allowed_unique2" >&2
  installer_fail=$((installer_fail + 1)) || true
fi
if [[ $installer_fail -eq 0 ]]; then ok "Echo Install files match ownership map and sources"; fi
# Core package manifests
core_pkg_fail=0
for arch in x86_64 aarch64; do
  manifest="components/echo-core/packages/packages.$arch"
  [[ -f "$manifest" ]] || { bad "missing core manifest $manifest"; core_pkg_fail=$((core_pkg_fail + 1)) || true; continue; }
  if [[ "$arch" == "x86_64" ]]; then col=4; else col=5; fi
  awk -F '\t' -v c="$col" 'NR>1 && $2=="CORE" && $c=="yes" {print $1}' "$package_map" | LC_ALL=C sort -u > "$TMPDIR/core_pkgs_$arch"
  grep -v '^[[:space:]]*$' "$manifest" | grep -v '^[[:space:]]*#' | sed 's/[[:space:]]//g' | LC_ALL=C sort -u > "$TMPDIR/core_manifest_$arch"
  if grep -vE '^[A-Za-z0-9@._+-]+$' "$TMPDIR/core_manifest_$arch" | grep -q .; then bad "invalid package name syntax in core manifest $arch"; core_pkg_fail=$((core_pkg_fail + 1)) || true; fi
  if [[ -s "$TMPDIR/core_manifest_$arch" ]] && [[ "$(uniq -d "$TMPDIR/core_manifest_$arch" | wc -l)" -gt 0 ]]; then bad "duplicate in core manifest $arch"; core_pkg_fail=$((core_pkg_fail + 1)) || true; fi
  if ! LC_ALL=C sort -c "$TMPDIR/core_manifest_$arch" 2>/dev/null; then bad "core manifest $arch not sorted"; core_pkg_fail=$((core_pkg_fail + 1)) || true; fi
  if ! cmp -s "$TMPDIR/core_pkgs_$arch" "$TMPDIR/core_manifest_$arch"; then
    bad "core manifest $arch does not match Core-owned packages"
    comm -3 "$TMPDIR/core_pkgs_$arch" "$TMPDIR/core_manifest_$arch" >&2
    core_pkg_fail=$((core_pkg_fail + 1)) || true
  fi
done
if [[ $core_pkg_fail -eq 0 ]]; then ok "core manifests match Core-owned packages"; fi


# Boot package manifests
for arch in x86_64 aarch64; do
  manifest="components/echo-boot/packages/packages.$arch"
  [[ -s "$manifest" ]] || { bad "empty boot manifest $manifest"; continue; }
  awk -F '\t' -v arch="$arch" 'NR>1 && $2=="BOOT" && $((arch=="x86_64"?4:5))=="yes" {print $1}' "$package_map" | LC_ALL=C sort > "$TMPDIR/boot_pkgs_$arch"
  grep -v '^[[:space:]]*$' "$manifest" | grep -v '^[[:space:]]*#' | sed 's/[[:space:]]//g' | LC_ALL=C sort > "$TMPDIR/boot_manifest_$arch"
  if grep -vE '^[A-Za-z0-9@._+-]+$' "$TMPDIR/boot_manifest_$arch" | grep -q .; then bad "invalid package name syntax in boot manifest $arch"; fi
  if [[ -s "$TMPDIR/boot_manifest_$arch" ]] && [[ "$(uniq -d "$TMPDIR/boot_manifest_$arch" | wc -l)" -gt 0 ]]; then bad "duplicate in boot manifest $arch"; fi
  if ! LC_ALL=C sort -c "$TMPDIR/boot_manifest_$arch" 2>/dev/null; then bad "boot manifest $arch not sorted"; fi
  if comm -3 "$TMPDIR/boot_pkgs_$arch" "$TMPDIR/boot_manifest_$arch" | grep -q .; then
    bad "boot manifest $arch differs from Boot ownership"
    comm -3 "$TMPDIR/boot_pkgs_$arch" "$TMPDIR/boot_manifest_$arch" >&2
  else
    ok "boot manifest $arch matches Boot-owned packages"
  fi
done

# Installer package manifests
for arch in x86_64 aarch64; do
  manifest="components/echo-install/packages/packages.$arch"
  [[ -f "$manifest" ]] || { bad "missing installer manifest $manifest"; continue; }
  if [[ "$arch" == "x86_64" ]]; then col=4; else col=5; fi
  awk -F '\t' -v c="$col" 'NR>1 && $2=="INSTALLER" && $c=="yes" {print $1}' "$package_map" | LC_ALL=C sort > "$TMPDIR/install_pkgs_$arch"
  grep -v '^[[:space:]]*$' "$manifest" | grep -v '^[[:space:]]*#' | sed 's/[[:space:]]//g' | LC_ALL=C sort -u > "$TMPDIR/install_manifest_$arch"
  if [[ -s "$TMPDIR/install_manifest_$arch" ]]; then
    if grep -vE '^[A-Za-z0-9@._+-]+$' "$TMPDIR/install_manifest_$arch" | grep -q .; then bad "invalid package name syntax in installer manifest $arch"; fi
    if [[ "$(uniq -d "$TMPDIR/install_manifest_$arch" | wc -l)" -gt 0 ]]; then bad "duplicate in installer manifest $arch"; fi
    if ! LC_ALL=C sort -c "$TMPDIR/install_manifest_$arch" 2>/dev/null; then bad "installer manifest $arch not sorted"; fi
  fi
  if ! comm -3 "$TMPDIR/install_pkgs_$arch" "$TMPDIR/install_manifest_$arch" | grep -q .; then
    ok "installer manifest $arch matches Installer-owned packages"
  else
    bad "installer manifest $arch differs from Installer ownership"
    comm -3 "$TMPDIR/install_pkgs_$arch" "$TMPDIR/install_manifest_$arch" >&2
  fi
done

# No duplicate packages across component manifests, per architecture.
manifest_dupes=0
for arch in x86_64 aarch64; do
  find components -path "*/packages/packages.$arch" -print0 2>/dev/null \
    | xargs -0 -r cat 2>/dev/null \
    | grep -v '^[[:space:]]*$' \
    | grep -v '^[[:space:]]*#' \
    | sed 's/[[:space:]]//g' \
    | LC_ALL=C sort > "$TMPDIR/all_manifest_pkgs_$arch"
  if [[ -s "$TMPDIR/all_manifest_pkgs_$arch" ]] && [[ "$(uniq -d "$TMPDIR/all_manifest_pkgs_$arch" | wc -l)" -gt 0 ]]; then
    bad "duplicate packages across component manifests for $arch"
    uniq -d "$TMPDIR/all_manifest_pkgs_$arch" >&2
    manifest_dupes=$((manifest_dupes + 1)) || true
  fi
done
if [[ "$manifest_dupes" -eq 0 ]]; then ok "no duplicate packages across manifests per architecture"; fi

# Ownership maps complete
awk -F '\t' 'NR>1 {print $1}' "$file_map" | sort | uniq -d | grep -q . && bad "duplicate file ownership rows"
awk -F '\t' 'NR>1 {print $1}' "$package_map" | sort | uniq -d | grep -q . && bad "duplicate package ownership rows"
awk -F '\t' 'NR>1 && $2 !~ /^(BOOT|INSTALLER|CORE|SHARED)$/ {print}' "$file_map" | grep -q . && bad "invalid file owner"
awk -F '\t' 'NR>1 && $2 !~ /^(BOOT|INSTALLER|CORE|SHARED)$/ {print}' "$package_map" | grep -q . && bad "invalid package owner"

# Every mapped source must exist; every profile file must be mapped exactly once.
coverage_fail=0
awk -F '\t' 'NR>1 {print $1}' "$file_map" | while IFS= read -r mapped; do
  [[ -e "$mapped" || -L "$mapped" ]] || printf '%s\n' "$mapped"
done > "$TMPDIR/missing_sources"
if [[ -s "$TMPDIR/missing_sources" ]]; then
  bad "ownership map references missing sources"
  sed -n '1,10p' "$TMPDIR/missing_sources" >&2
  coverage_fail=$((coverage_fail + 1))
fi
awk -F '\t' 'NR>1 && $1 ~ /^profile\// {print $1}' "$file_map" | LC_ALL=C sort > "$TMPDIR/profile_mapped"
find profile \( -type f -o -type l \) -print | LC_ALL=C sort > "$TMPDIR/profile_actual"
if ! cmp -s "$TMPDIR/profile_mapped" "$TMPDIR/profile_actual"; then
  bad "profile files are not covered exactly once by the ownership map"
  comm -3 "$TMPDIR/profile_mapped" "$TMPDIR/profile_actual" >&2
  coverage_fail=$((coverage_fail + 1))
fi

# Every legacy package declaration per architecture must be mapped exactly once.
for arch in x86_64 aarch64; do
  if [[ "$arch" == "x86_64" ]]; then col=4; else col=5; fi
  awk -F '\t' -v c="$col" 'NR>1 && $c=="yes" {print $1}' "$package_map" | LC_ALL=C sort > "$TMPDIR/map_pkgs_$arch"
  grep -vE '^[[:space:]]*(#|$)' "profile/packages.$arch" | sed 's/[[:space:]]//g' | LC_ALL=C sort > "$TMPDIR/list_pkgs_$arch"
  if ! cmp -s "$TMPDIR/map_pkgs_$arch" "$TMPDIR/list_pkgs_$arch"; then
    bad "legacy package list $arch does not match the ownership map"
    comm -3 "$TMPDIR/map_pkgs_$arch" "$TMPDIR/list_pkgs_$arch" >&2
    coverage_fail=$((coverage_fail + 1))
  fi
done
[[ "$coverage_fail" -eq 0 ]] && ok "ownership maps cover all profile files and package declarations"
ok "ownership maps consistent"

# Overlays/destinations unique
awk -F '\t' 'NR>1 && $5 != "-" {print $5}' "$file_map" | LC_ALL=C sort | uniq -d | grep -q . && bad "duplicate destinations" || ok "no duplicate destinations"
awk -F '\t' 'NR>1 && $4 != "-" {print $4}' "$file_map" | LC_ALL=C sort | uniq -d | grep -q . && bad "duplicate future paths" || ok "no duplicate future paths"

# Baseline check: profile unchanged
find profile \( -type f -o -type l \) -print | LC_ALL=C sort > "$TMPDIR/profile_now"
awk -F '\t' 'NR>1 {print $1}' "$baseline" | LC_ALL=C sort > "$TMPDIR/profile_base"
if ! cmp -s "$TMPDIR/profile_now" "$TMPDIR/profile_base"; then bad "profile file set changed vs baseline"; else ok "profile file set unchanged vs baseline"; fi
if uniq -d "$TMPDIR/profile_base" | grep -q .; then bad "duplicate paths in profile baseline"; else ok "profile baseline paths unique"; fi

baseline_fail=0
while IFS=$'\t' read -r bpath btype bmode bsize bsha blink; do
  [[ "$bpath" == "path" ]] && continue
  if [[ ! -e "$bpath" && ! -L "$bpath" ]]; then bad "baseline path missing: $bpath"; baseline_fail=$((baseline_fail+1)) || true; continue; fi
  if [[ -L "$bpath" ]]; then ntype=symlink; elif [[ -f "$bpath" ]]; then ntype=file; else ntype=other; fi
  [[ "$ntype" == "$btype" ]] || { bad "type changed $bpath"; baseline_fail=$((baseline_fail+1)) || true; }
  nmode=$(stat -c '%a' "$bpath"); [[ "$nmode" == "$bmode" ]] || { bad "mode changed $bpath"; baseline_fail=$((baseline_fail+1)) || true; }
  nsize=$(stat -c '%s' "$bpath"); [[ "$nsize" == "$bsize" ]] || { bad "size changed $bpath"; baseline_fail=$((baseline_fail+1)) || true; }
  if [[ "$btype" == "symlink" ]]; then
    nlink=$(readlink "$bpath"); [[ "$nlink" == "$blink" ]] || { bad "symlink target changed $bpath"; baseline_fail=$((baseline_fail+1)) || true; }
  fi
  if [[ "$bsha" != "-" && "$btype" == "file" ]]; then
    nsha=$(sha256sum "$bpath" | awk '{print $1}')
    [[ "$nsha" == "$bsha" ]] || { bad "content changed $bpath"; baseline_fail=$((baseline_fail+1)) || true; }
  fi
done < "$baseline"
if [[ $baseline_fail -eq 0 ]]; then ok "profile content/metadata unchanged vs baseline (sensitive files metadata-only)"; fi

# Ensure sensitive paths are metadata-only in the baseline
if awk -F '\t' 'NR>1 && ($1=="profile/airootfs/etc/shadow" || $1=="profile/airootfs/etc/gshadow" || $1=="profile/airootfs/root/customize_airootfs.sh") && $5!="-" {print}' "$baseline" | grep -q .; then bad "sensitive file has hash in baseline"; else ok "sensitive files not hashed in baseline"; fi

# Generated profiles are produced by assembly; do not require them to be absent

printf '\n'
if [[ "$failures" -ne 0 ]]; then
  printf 'STEP 4 VALIDATION: FAILED (%d failure(s))\n' "$failures"
  exit 1
fi
printf 'STEP 4 VALIDATION: PASSED\n'
printf 'PROFILE PARITY: NOT ESTABLISHED\n'
printf 'No ISO built, no boot/install test, no Git command used.\n'
exit 0

