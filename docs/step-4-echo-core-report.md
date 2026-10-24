# Step 4 — Echo Core Migration Report

## Scope
- Repository: HomieTal/EchoOS-DEV (working tree at /home/ghost/Desktop/EchoOS-DEV)
- Steps completed: 1–3 prior; Step 4 executed per the provided instructions.
- No ISO generated, no boot/install tests, no Git commands used. Original profile left intact.

## Audit (Phase 1)
- `git status --short`: pre-existing modifications in `profile/` (and untracked `build/`, `components/`, `docs/`) preserved (no deletions/overwrites of user work).
- Ownership maps inspected: `build/config/legacy-file-owners.tsv` (BOOT 15, CORE 66, INSTALLER 21, SHARED 16), `build/config/legacy-package-owners.tsv` (BOOT 8, CORE 150 declared across arches in map; INSTALLER 1).
- Profile contents inventoried; classification by owner performed using maps.
- Sources identified from maps (`legacy_path` -> `future_path` in components).

## Boundaries (Phase 2)
- Boot: bootloader/boot infrastructure (unchanged).
- Install: Calamares + installer config/policies (unchanged).
- Core: base OS configuration + package declarations (migrated per verified ownership).
- Shared build: templates/assembly logic (separate; not migrated into Core).

No cross-component duplication introduced. No new features added.

## Core payload migration (Phase 3)
All 66 CORE files from `build/config/legacy-file-owners.tsv` were copied/symlinked to their mapped locations under `components/echo-core/` with contents/perms/symlinks preserved:
- `components/echo-core/airootfs/*` (COMMON/live-intended target configs where mapped)
- `components/echo-core/live/*` (LIVE-EXCLUDED/LIVE-INTENDED live assets, hooks, units, helpers, credentials-related live files) — note sensitive live files (`etc/shadow`, `etc/passwd`, `root/customize_airootfs.sh`) preserved as-is per source

Package manifests generated from verified source declarations (no invention):
- `components/echo-core/packages/packages.x86_64`: 148 packages (sorted, unique) — matches CORE x86_64 entries in map
- `components/echo-core/packages/packages.aarch64`: 141 packages (sorted, unique) — matches CORE aarch64 entries in map
No package appears in multiple component manifests.

## Shared-template investigation (Phase 4)
Searched profile/history/maps/scripts/README; found authoritative sources in `profile/` and render script:
| Missing input | Expected path | Purpose (from assemble.sh/maps) | Authoritative source found | Status | Recommendation |
| --- | --- | --- | --- | --- | --- |
| `profiledef.sh` (shared) | `build/template/profiledef.sh` | ArchISO profile metadata/bootmodes/file_permissions/pacman_conf | `profile/profiledef.sh` (present, project-specific values: iso_name/label/publisher/application/version, bootmodes bios.syslinux + uefi.systemd-boot, pacman_conf, image options, file_permissions). `build/template/README.md` says derive template but not introduce copies before assembly review. | Unresolved (not copied) | Do **not** copy/move now. When implementing assembly, derive `build/template/profiledef.sh` from `profile/profiledef.sh` preserving bootmodes/permissions and only parameterize what the contract requires. |
| `bootstrap_packages` (shared) | `build/template/bootstrap_packages` | Bootstrap packages for archiso bootstrap | `profile/bootstrap_packages` contains `arch-install-scripts` and `base`. `build/config/legacy-file-owners.tsv` maps it as SHARED BUILD -> `build/template/bootstrap_packages`. | Unresolved (not copied) | Copy/derive in assembly step if needed; keep ordering/content identical to authoritative source. |
| `pacman.conf.in` (shared) | `build/config/pacman.conf.in` | Build-time pacman template | Exists as `profile/pacman.conf.in` (authoritative template with `@LOCAL_REPO_PATH@` placeholder and `[echo]` local repo). Map says SHARED BUILD -> `build/config/pacman.conf.in`. `scripts/render-pacman-conf.sh` renders `profile/pacman.conf` from it. | Unresolved (not copied) | Move/copy to `build/config/pacman.conf.in` when template layout is finalized; ensure render script paths updated or both remain consistent. Do not guess contents. |

Notes:
- `profile/pacman.conf` is machine-specific/generated (contains absolute path) per map; not a template.
- `build/template/` intentionally empty of copies per README (avoid competing sources of truth).
- No new templates invented.

## Validation (Phase 5)
Extended `build/validate.sh` to verify:
- Echo Core files match ownership map sources (byte-for-byte/content/mode/symlink)
- Core manifests match verified declarations per arch
- No duplicate package ownership; ownership maps cover all profile files/packages
- Boot/Install remain unchanged
- Failure path correctly returns non-zero (tested on disposable copy)

Commands run:
```bash
./build/validate.sh  # RC 0
git diff --check
git status --short
```
Results:
- `./build/validate.sh`: **RC 0**  
  `STEP 4 VALIDATION: PASSED`  
  `PROFILE PARITY: NOT ESTABLISHED`  
  All Boot/Install/Core checks passed (manifests match, no cross-component duplicates, ownership coverage OK, profile baseline unchanged, no generated profile).
- `git diff --check`: clean (no whitespace errors)
- `git status --short`: only pre-existing modifications in `profile/` and untracked `build/`, `components/`, `docs/` (no changes to Boot/profile by validator; Core payloads/manifests added under `components/echo-core/` as expected)

Failure-path test (disposable copy): removing `components/echo-core/live/etc/motd` caused validator to report failures and return **RC 1** (correct behavior).

## Preservation
- `components/echo-boot/` unchanged.
- `profile/` not modified by validation/migration (pre-existing local modifications remain untouched).
- Calamares 3.4.2 config/sequence and boot behavior unchanged.
- No ISO/profile generated.

## Remaining blockers
- Shared templates were subsequently resolved in `docs/shared-template-resolution-report.md`
  (`build/template/profiledef.sh`, `build/template/bootstrap_packages`,
  `build/config/pacman.conf.in`), with validator-enforced parity to `profile/`.
- `build/assemble.sh` remains a non-generating stub (RC 2); implementation not done.
- Profile parity not established.

## Next action
Implement assembly only after shared templates are placed/derived per contract and validated; do **not** change Boot/Install/profile. Core migration complete for Step 4.
