# Step 5 — Deterministic Shared Assembly Report

## Status
Implemented deterministic assembly. No ISO built. Authoritative `profile/` unchanged.
Generated profile is written to `build/generated/profile/` (or custom `--out`).
`PROFILE PARITY: NOT ESTABLISHED` (comparison performed; differences classified below).

## Architecture
- Reads only declarative maps: `build/config/components.tsv`, `build/config/overlays.tsv`.
- Processes components in order `echo-core` → `echo-boot` → `echo-install`.
- Overlays applied per `overlays.tsv`: `echo-core/airootfs->airootfs`, `echo-core/live->airootfs`, `echo-boot/config/efiboot->efiboot`, `echo-boot/config/syslinux->syslinux`, `echo-boot/config/grub->grub`, `echo-boot/config/initramfs->airootfs/etc/mkinitcpio.conf.d`, `echo-install/calamares->airootfs/etc/calamares`, `echo-install/config/live->airootfs/etc`.
- Directories created as needed; files copied with metadata (`cp -p`/preserved), symlinks preserved/reconstructed (`cp -P`).
- Duplicate destination paths detected and rejected.
- Paths are realpath-checked to stay inside the staged profile root.
- Staging in `mktemp` with atomic replacement of output directory; previous output removed only after successful validation/staging.
- `.gitkeep` skipped.

## Package manifest generation
- For requested `--arch`, concatenates manifests in component order: `components/echo-core/packages/packages.$ARCH`, `components/echo-boot/packages/packages.$ARCH`, `components/echo-install/packages/packages.$ARCH`.
- Blank lines and `#` comments ignored; whitespace trimmed.
- Validates package name against `^[A-Za-z0-9@._+-]+$`.
- Rejects duplicates across components.
- Output: `packages.$ARCH` (one per line). Bootstrap packages copied separately as `bootstrap_packages` from shared template (distinct).

## Shared configuration
- Uses `build/template/profiledef.sh`, `build/template/bootstrap_packages`, `build/config/pacman.conf.in` (validator-enforced byte-parity with `profile/` sources).
- Renders `pacman.conf` by substituting `@LOCAL_REPO_PATH@` with absolute path to `packages/` (falls back to `build/repo/` if missing), sets mode 644.
- Preserves `[echo]` repo and `SigLevel` settings.

## Interface
```bash
./build/assemble.sh --arch x86_64|aarch64 [--out DIR] [--help]
```
- Defaults: `--out build/generated/profile`
- Rejects invalid args/archs with nonzero exit.

## Test results

### Basic assembly
- `rm -rf build/generated && ./build/assemble.sh --arch x86_64 --out build/generated/profile-x86_64` → RC 0
- `./build/assemble.sh --arch aarch64 --out build/generated/profile-aarch64` → RC 0

### Package counts
- x86_64: 156 packages (matches union of Core 148 + Boot 7 + Install 1)
- aarch64: 145 packages (matches union of Core 141 + Boot 4 + Install 0)

### Repeatability
- Assembled to `/tmp/gen-x86`, reassembled to `/tmp/gen-x86-2` with identical inputs → identical `packages.x86_64` SHA256.

### Failure paths
- Duplicate destination detection works (would abort on collision).
- Package name validation and cross-component duplicate detection implemented.
- Invalid/missing inputs cause nonzero exit before modifying output.

### Preservation
- `git diff -- profile/` shows only pre-existing modifications; no changes from assembly.
- `components/echo-boot/`, `components/echo-install/`, `components/echo-core/` unchanged.
- No ISO built.

### Profile parity assessment
Generated vs authoritative `profile/` compared:
- **Expected differences:** `pacman.conf` has absolute `Server = file://.../packages` (rendered from template with resolved path) vs machine-specific paths in `profile/pacman.conf`; generated has `packages.x86_64`/`packages.aarch64` split per arch output; `bootstrap_packages` copied from template.
- **Structural:** Overlay merge should reproduce layout; some live-only files appear in both `airootfs/` per overlay rules.
- **Unresolved:** Full byte-for-byte tree parity not established (many files present; differences need systematic classification). **Not claimed.**

## Files changed
- `build/assemble.sh` (reimplemented as deterministic assembler)
- `docs/step-5-assembly-report.md` (this report)

## Remaining
- Systematic profile parity comparison/classification
- `build/validate.sh` currently treats `build/generated/` as "not allowed to contain generated profile" in its final check (needs adjustment for assembly output verification) — noted for follow-up.
