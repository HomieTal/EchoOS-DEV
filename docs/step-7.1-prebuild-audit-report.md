# Step 7.1 — Pre-Build Safety and Environment Audit

## Git and working tree
- Repository: `/home/ghost/Desktop/EchoOS-DEV`
- Branch: `* main`
- `git status --short` (pre-existing user changes preserved):
  - `M profile/airootfs/etc/calamares/modules/unpackfs/exclude-list.txt`
  - `M profile/airootfs/etc/polkit-1/rules.d/50-calamares.rules`
  - `M profile/airootfs/etc/shadow`
  - `M profile/airootfs/etc/systemd/system/display-manager.service`
  - `M profile/packages.aarch64`
  - `M profile/packages.x86_64`
  - `M profile/profiledef.sh`
  - `?? build/` (untracked component/build artifacts)
  - `?? components/`
  - `?? docs/`
  - `?? profile/airootfs/etc/security/`
  - `?? profile/airootfs/root/customize_airootfs.sh`

No changes made to tracked files by this audit.

## Validator
- Command: `./build/validate.sh`
- Exit code: **0**
- Result: `STEP 4 VALIDATION: PASSED`, `PROFILE PARITY: NOT ESTABLISHED` (per current validator text)
- All component/ownership/template/package checks pass.

## Assembly (fresh outputs, outside profile/)
- `./build/assemble.sh --arch x86_64 --out /tmp/audit-x86` → **RC 0**
- `./build/assemble.sh --arch aarch64 --out /tmp/audit-arm` → **RC 0**

### Package lists
- x86_64: **156** packages (matches Core 148 + Boot 7 + Install 1)
- aarch64: **145** packages (matches Core 141 + Boot 4 + Install 0)
- Sets match verified component manifests; order follows component order with deduplication.

### Pacman configuration
- Rendered from `build/config/pacman.conf.in` with `@LOCAL_REPO_PATH@` → absolute path
- Resolved to: `Server = file:///home/ghost/Desktop/EchoOS-DEV/packages`
- `[echo]` repo present; placeholder removed. Permitted difference per Step 6 contract.

### Live-user home
- `/tmp/audit-x86/airootfs/home/archiso/` exists with mode **750**, uid:gid **1000:1000** (matches required live-user config).

## Build prerequisites (read-only)
- `mkarchiso`: **/usr/bin/mkarchiso** present (archiso **91-1** installed)
- Host: Arch Linux (kernel 7.2.11-arch1-1)
- Required tools generally available via archiso; no packages installed/upgraded by audit.
- Disk space: root `/` has 107GB free, `/tmp` 7.7GB free (sufficient for typical archiso build; actual usage depends on cache)
- Local repo: `packages/` exists with `echo.db*` and `calamares-3.4.2-2-x86_64.pkg.tar.zst`; `build/repo/` also contains the package copy. Assembler resolves repo from `packages/`.
- Output paths: writable.

## Profile/config inspection (assembled)
- `profiledef.sh`: bootmodes include `bios.syslinux`, `uefi.systemd-boot`; `pacman_conf="pacman.conf"`; image options present.
- Boot assets: efiboot/syslinux/grub files present.
- Calamares: `airootfs/etc/calamares/settings.conf` present with modules.
- Hooks/airootfs payloads present as assembled from components.

## Protections
- No modifications to `profile/`, Boot, or Install components.
- No ISO built, no mkarchiso invoked.
- No packages installed/upgraded.
- Pre-existing user changes preserved.

## Status
**READY WITH WARNINGS**

### Warnings (non-blocking, documented)
- `build/` and `components/` are untracked in this working tree (expected per workflow).
- `build/generated/` may contain outputs from prior runs (not removed).
- The local `[echo]` repo uses absolute file paths; build environment must have access to those paths.
- Network may be needed for official repos depending on pacman.conf/mirrors; not verified.

### Blockers
- None identified for a read-only build attempt using the assembled profile and existing local repo.

## Commands executed
- `git branch -a`, `git status --short`, `pwd`, `uname -a`
- `./build/validate.sh` (RC 0)
- `which mkarchiso`, `pacman -Q archiso`, `mkarchiso --version` (partial)
- `./build/assemble.sh --arch x86_64 --out /tmp/audit-x86` (RC 0)
- `./build/assemble.sh --arch aarch64 --out /tmp/audit-arm` (RC 0)
- Various read-only inspections (package counts, pacman.conf, permissions, disk space, repo contents)

No ISO build commands executed.
