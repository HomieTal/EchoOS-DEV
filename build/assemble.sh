#!/usr/bin/env bash
# Echo OS deterministic assembly (Step 5)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: build/assemble.sh --arch x86_64|aarch64 [--out DIR] [--help]
USAGE
}

ARCH=""
OUTDIR="build/generated/profile"
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --arch)
      if [ $# -lt 2 ]; then echo "assemble: --arch requires a value" >&2; exit 2; fi
      ARCH="$2"; shift 2 ;;
    --out)
      if [ $# -lt 2 ]; then echo "assemble: --out requires a value" >&2; exit 2; fi
      OUTDIR="$2"; shift 2 ;;
    *) echo "assemble: unsupported argument: $1" >&2; exit 2 ;;
  esac
done

[ -z "$ARCH" ] && { echo "assemble: --arch required" >&2; usage >&2; exit 2; }
[ "$ARCH" = "x86_64" ] || [ "$ARCH" = "aarch64" ] || { echo "assemble: unsupported arch" >&2; exit 2; }

OUTDIR_ABS="$(mkdir -p "$(dirname "$OUTDIR")" && cd "$(dirname "$OUTDIR")" && pwd)/$(basename "$OUTDIR")"

components_map=build/config/components.tsv
overlays_map=build/config/overlays.tsv

for f in "$components_map" "$overlays_map" build/config/pacman.conf.in build/template/profiledef.sh build/template/bootstrap_packages; do
  [ -s "$f" ] || { echo "assemble: missing $f" >&2; exit 2; }
done
cmp -s profile/profiledef.sh build/template/profiledef.sh || { echo "assemble: template drift" >&2; exit 2; }
cmp -s profile/bootstrap_packages build/template/bootstrap_packages || { echo "assemble: template drift" >&2; exit 2; }
cmp -s profile/pacman.conf.in build/config/pacman.conf.in || { echo "assemble: template drift" >&2; exit 2; }

missing=0
awk -F'\t' 'NR>1{print}' "$components_map" | while IFS=$'\t' read -r order component component_root requires; do
  [ -d "$component_root" ] && [ -s "$component_root/README.md" ] || missing=$((missing+1))
  for arch in x86_64 aarch64; do [ -f "$component_root/packages/packages.$arch" ] || missing=$((missing+1)); done
done
# simpler check
missing=0
while IFS=$'\t' read -r order component component_root requires; do
  [ "$order" = "order" ] && continue
  if [ ! -d "$component_root" ] || [ ! -s "$component_root/README.md" ]; then missing=$((missing+1)); fi
  for arch in x86_64 aarch64; do
    if [ ! -f "$component_root/packages/packages.$arch" ]; then missing=$((missing+1)); fi
  done
done < "$components_map"
[ $missing -ne 0 ] && exit 2

while IFS=$'\t' read -r component source_prefix destination_prefix; do
  [ "$component" = "component" ] && continue
  if [ ! -d "components/$component/$source_prefix" ]; then echo "assemble: missing source" >&2; exit 2; fi
done < "$overlays_map"

TMPDIR_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/echo-assemble.XXXXXX")"
trap 'rm -rf "$TMPDIR_STAGE"' EXIT
STAGE="$TMPDIR_STAGE/profile"
mkdir -p "$STAGE"

# assemble
while IFS=$'\t' read -r order component component_root requires; do
  [ "$order" = "order" ] && continue
  while IFS=$'\t' read -r ocomp osrc odst; do
    [ "$ocomp" = "component" ] && continue
    [ "$ocomp" = "$component" ] || continue
    srcbase="components/$component/$osrc"
    [ -d "$srcbase" ] || continue
    # use python for robust copy
    python3 - "$srcbase" "$STAGE/$odst" "$ROOT" << 'PY'
import os, sys, shutil
srcbase = sys.argv[1]
dstdir = sys.argv[2]
root = sys.argv[3]
for rootdir, dirs, files in os.walk(srcbase):
    for d in dirs:
        if d == '.gitkeep':
            continue
        sp = os.path.join(rootdir, d)
        rel = os.path.relpath(sp, srcbase)
        if rel == '.':
            continue
        dp = os.path.join(dstdir, rel)
        os.makedirs(dp, exist_ok=True)
        try:
            st = os.lstat(sp)
            os.chmod(dp, st.st_mode & 0o7777)
        except Exception:
            pass
    for f in files:
        if f == '.gitkeep':
            continue
        sp = os.path.join(rootdir, f)
        if os.path.islink(sp):
            rel = os.path.relpath(sp, srcbase)
            dp = os.path.join(dstdir, rel)
            os.makedirs(os.path.dirname(dp), exist_ok=True)
            if os.path.lexists(dp):
                os.unlink(dp)
            os.symlink(os.readlink(sp), dp)
            try:
                st = os.lstat(sp)
                os.lchmod(dp, st.st_mode & 0o7777)
            except Exception:
                pass
            continue
        if os.path.isfile(sp):
            rel = os.path.relpath(sp, srcbase)
            dp = os.path.join(dstdir, rel)
            os.makedirs(os.path.dirname(dp), exist_ok=True)
            if os.path.lexists(dp):
                print('DUP:' + dp, file=sys.stderr)
                sys.exit(2)
            shutil.copy2(sp, dp)
            continue
PY
  done < "$overlays_map"
done < "$components_map"

# packages
dupcheck="$TMPDIR_STAGE/pkgseen"
: > "$dupcheck"
: > "$STAGE/packages.$ARCH"
while IFS=$'\t' read -r order component component_root requires; do
  [ "$order" = "order" ] && continue
  manifest="$component_root/packages/packages.$ARCH"
  while read -r line; do
    # trim
    line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    echo "$line" | grep -Eq '^[A-Za-z0-9@._+-]+$' || { echo "assemble: bad pkg" >&2; exit 2; }
    grep -Fxq "$line" "$dupcheck" && { echo "assemble: dup pkg" >&2; exit 2; }
    echo "$line" >> "$dupcheck"
    echo "$line" >> "$STAGE/packages.$ARCH"
  done < "$manifest"
done < "$components_map"

cp -p build/template/profiledef.sh "$STAGE/profiledef.sh"
cp -p build/template/bootstrap_packages "$STAGE/bootstrap_packages"
REPO_PATH_ABS="$(cd "$ROOT/packages" && pwd)"
sed "s|@LOCAL_REPO_PATH@|${REPO_PATH_ABS}|g" build/config/pacman.conf.in > "$STAGE/pacman.conf"
chmod 644 "$STAGE/pacman.conf"

mkdir -p "$(dirname "$OUTDIR_ABS")"
if [ -e "$OUTDIR_ABS" ]; then
  rm -rf "${OUTDIR_ABS}.old" 2>/dev/null || true
  mv "$OUTDIR_ABS" "${OUTDIR_ABS}.old" 2>/dev/null || true
fi
mv "$STAGE" "$OUTDIR_ABS"
rm -rf "${OUTDIR_ABS}.old" 2>/dev/null || true
echo "Assembled profile for $ARCH in $OUTDIR_ABS"
exit 0
