#!/usr/bin/env bash
# Echo OS deterministic assembly.
#
# Reads the component trees and declarative maps, then writes a complete
# ArchISO profile to build/generated/profile (or --out).  The legacy profile/
# tree is a read-only reference and is never modified.
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

for f in "$components_map" "$overlays_map" build/config/pacman.conf.in \
         build/template/profiledef.sh build/template/bootstrap_packages; do
  [ -s "$f" ] || { echo "assemble: missing $f" >&2; exit 2; }
done

# ---------------------------------------------------------------------------
# Validate component definitions, order, and dependencies.
# ---------------------------------------------------------------------------
declare -A seen_order=() seen_component=() component_order=() component_root=() component_requires=()
last_order=0
while IFS=$'\t' read -r order component root requires; do
  [ "$order" = "order" ] && continue
  [[ "$order" =~ ^[0-9]+$ ]] || { echo "assemble: invalid component order: $order" >&2; exit 2; }
  [ -n "$component" ] && [ -n "$root" ] || { echo "assemble: incomplete component row" >&2; exit 2; }
  [ -z "${seen_order[$order]:-}" ] || { echo "assemble: duplicate component order: $order" >&2; exit 2; }
  [ -z "${seen_component[$component]:-}" ] || { echo "assemble: duplicate component: $component" >&2; exit 2; }
  [ "$order" -ge "$last_order" ] || { echo "assemble: component order is not ascending" >&2; exit 2; }
  seen_order[$order]=1
  seen_component[$component]=1
  component_order[$component]=$order
  component_root[$component]=$root
  component_requires[$component]="$requires"
  last_order=$order
  [ -d "$root" ] || { echo "assemble: missing component root: $root" >&2; exit 2; }
  [ -s "$root/README.md" ] || { echo "assemble: missing component README: $root/README.md" >&2; exit 2; }
  for a in x86_64 aarch64; do
    [ -f "$root/packages/packages.$a" ] || { echo "assemble: missing manifest: $root/packages/packages.$a" >&2; exit 2; }
  done
done < "$components_map"

while IFS=$'\t' read -r order component root requires; do
  [ "$order" = "order" ] && continue
  [ "$requires" = "-" ] && continue
  IFS=',' read -ra reqs <<< "$requires"
  for req in "${reqs[@]}"; do
    [ -n "$req" ] || continue
    [ -n "${seen_component[$req]:-}" ] || { echo "assemble: $component depends on unknown component $req" >&2; exit 2; }
    [ "${component_order[$req]}" -lt "${component_order[$component]}" ] || {
      echo "assemble: $component depends on $req but order is not lower" >&2; exit 2; }
  done
done < "$components_map"

# ---------------------------------------------------------------------------
# Validate overlays before writing anything.
# ---------------------------------------------------------------------------
while IFS=$'\t' read -r component source_prefix destination_prefix; do
  [ "$component" = "component" ] && continue
  [ -n "${seen_component[$component]:-}" ] || { echo "assemble: overlay for unknown component: $component" >&2; exit 2; }
  [ -e "components/$component/$source_prefix" ] || [ -L "components/$component/$source_prefix" ] || { echo "assemble: missing overlay source: components/$component/$source_prefix" >&2; exit 2; }
  case "$destination_prefix" in
    ""|/*|..|../*|*/..|*/../*) echo "assemble: unsafe overlay destination: $destination_prefix" >&2; exit 2 ;;
  esac
done < "$overlays_map"

TMPDIR_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/echo-assemble.XXXXXX")"
trap 'rm -rf "$TMPDIR_STAGE"' EXIT
STAGE="$TMPDIR_STAGE/profile"
mkdir -p "$STAGE"

# ---------------------------------------------------------------------------
# Merge overlays.  Duplicate destination paths are hard errors.
# ---------------------------------------------------------------------------
while IFS=$'\t' read -r order component root requires; do
  [ "$order" = "order" ] && continue
  while IFS=$'\t' read -r ocomp osrc odst; do
    [ "$ocomp" = "component" ] && continue
    [ "$ocomp" = "$component" ] || continue
    srcbase="components/$component/$osrc"
    if [ -f "$srcbase" ] || [ -L "$srcbase" ]; then
      dstfile="$STAGE/$odst"
      if [ -e "$dstfile" ] || [ -L "$dstfile" ]; then
        echo "assemble: duplicate destination: $dstfile" >&2
        exit 2
      fi
      mkdir -p "$(dirname "$dstfile")"
      python3 - "$srcbase" "$dstfile" <<'PY'
import os, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
if os.path.islink(src):
    os.symlink(os.readlink(src), dst)
    try:
        os.lchmod(dst, os.lstat(src).st_mode & 0o7777)
    except Exception:
        pass
else:
    shutil.copy2(src, dst)
PY
      continue
    fi
    python3 - "$ROOT/components/$component/$osrc" "$STAGE/$odst" "$STAGE" <<'PY'
import os, sys, shutil

srcbase, dstdir, stageroot = sys.argv[1], sys.argv[2], os.path.realpath(sys.argv[3])
dstdir = os.path.realpath(os.path.abspath(dstdir))
if os.path.commonpath([stageroot, dstdir]) != stageroot:
    print(f"assemble: destination escapes profile root: {dstdir}", file=sys.stderr)
    raise SystemExit(2)

for rootdir, dirs, files in os.walk(srcbase):
    for d in dirs:
        if d == '.gitkeep':
            continue
        sp = os.path.join(rootdir, d)
        rel = os.path.relpath(sp, srcbase)
        dp = os.path.join(dstdir, rel)
        if os.path.commonpath([stageroot, os.path.realpath(dp)]) != stageroot:
            print(f"assemble: destination escapes profile root: {dp}", file=sys.stderr)
            raise SystemExit(2)
        os.makedirs(dp, exist_ok=True)
        try:
            os.chmod(dp, os.lstat(sp).st_mode & 0o7777)
        except Exception:
            pass
    for f in files:
        if f == '.gitkeep':
            continue
        sp = os.path.join(rootdir, f)
        rel = os.path.relpath(sp, srcbase)
        dp = os.path.join(dstdir, rel)
        os.makedirs(os.path.dirname(dp), exist_ok=True)
        if os.path.lexists(dp):
            print('DUP:' + dp, file=sys.stderr)
            raise SystemExit(2)
        if os.path.islink(sp):
            os.symlink(os.readlink(sp), dp)
            try:
                os.lchmod(dp, os.lstat(sp).st_mode & 0o7777)
            except Exception:
                pass
        elif os.path.isfile(sp):
            shutil.copy2(sp, dp)
        else:
            print(f"assemble: unsupported file type: {sp}", file=sys.stderr)
            raise SystemExit(2)
PY
  done < "$overlays_map"
done < "$components_map"

# ---------------------------------------------------------------------------
# Resolve package manifests in component order.
# ---------------------------------------------------------------------------
dupcheck="$TMPDIR_STAGE/pkgseen"
: > "$dupcheck"
for a in x86_64 aarch64; do
  : > "$STAGE/packages.$a"
done

while IFS=$'\t' read -r order component root requires; do
  [ "$order" = "order" ] && continue
  manifest="$root/packages/packages.$ARCH"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    if ! [[ "$line" =~ ^[A-Za-z0-9@._+-]+$ ]]; then
      echo "assemble: invalid package name '$line' in $manifest" >&2
      exit 2
    fi
    if grep -Fxq "$line" "$dupcheck"; then
      echo "assemble: duplicate package '$line' in $manifest" >&2
      exit 2
    fi
    echo "$line" >> "$dupcheck"
    echo "$line" >> "$STAGE/packages.$ARCH"
  done < "$manifest"
done < "$components_map"

LC_ALL=C sort -u "$STAGE/packages.$ARCH" -o "$STAGE/packages.$ARCH"
# Explicitly create the other architecture's list empty; the caller only
# builds one architecture at a time.
for a in x86_64 aarch64; do
  [ -f "$STAGE/packages.$a" ] || : > "$STAGE/packages.$a"
done

# ---------------------------------------------------------------------------
# Shared profile files.
# ---------------------------------------------------------------------------
cp -p build/template/profiledef.sh "$STAGE/profiledef.sh"
cp -p build/template/bootstrap_packages "$STAGE/bootstrap_packages"
cp -p build/config/pacman.conf.in "$STAGE/pacman.conf.in"
REPO_PATH_ABS="$(cd "$ROOT/packages" && pwd)"
sed "s|@LOCAL_REPO_PATH@|${REPO_PATH_ABS}|g" build/config/pacman.conf.in > "$STAGE/pacman.conf"
chmod 644 "$STAGE/pacman.conf" "$STAGE/pacman.conf.in"

# ---------------------------------------------------------------------------
# Assembly manifest (outside the profile so it never reaches the ISO).
# ---------------------------------------------------------------------------
MANIFEST="$(dirname "$OUTDIR_ABS")/assembly-manifest.tsv"
python3 - "$STAGE" "$MANIFEST" <<'PY'
import os, sys
stage, manifest = sys.argv[1], sys.argv[2]
with open(manifest, 'w', encoding='utf-8') as out:
    out.write('path\ttype\tmode\n')
    for root, dirs, files in os.walk(stage):
        for name in sorted(dirs + files):
            p = os.path.join(root, name)
            rel = os.path.relpath(p, stage)
            if os.path.islink(p):
                kind = 'symlink'
                mode = oct(os.lstat(p).st_mode & 0o7777)[2:]
            elif os.path.isfile(p):
                kind = 'file'
                mode = oct(os.stat(p).st_mode & 0o7777)[2:]
            elif os.path.isdir(p):
                kind = 'dir'
                mode = oct(os.stat(p).st_mode & 0o7777)[2:]
            else:
                continue
            out.write(f'{rel}\t{kind}\t{mode}\n')
PY

# ---------------------------------------------------------------------------
# Publish atomically.
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$OUTDIR_ABS")"
if [ -e "$OUTDIR_ABS" ]; then
  rm -rf "${OUTDIR_ABS}.old" 2>/dev/null || true
  mv "$OUTDIR_ABS" "${OUTDIR_ABS}.old"
fi
mv "$STAGE" "$OUTDIR_ABS"
rm -rf "${OUTDIR_ABS}.old" 2>/dev/null || true

count=$(find "$OUTDIR_ABS" \( -type f -o -type l \) | wc -l)
echo "Assembled profile for $ARCH in $OUTDIR_ABS ($count files/symlinks)"
exit 0
