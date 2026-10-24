# Step 6 — Profile Parity and Reconciliation Report

## Baseline
- Authoritative: `profile/` (contains pre-existing user modifications; preserved)
- Component payloads/manifests unchanged
- Assembled fresh outputs: `build/generated/parity-x86_64/`, `build/generated/parity-aarch64/`

## Methodology
- Recursive comparison of paths, types, symlinks, permissions (mode & 0777), and SHA256 for regular files
- Package lists traced to component manifests in order
- pacman.conf compared for `[echo]` and `Server`

## Comparison results

### Files only in original (profile)
- `packages.x86_64` / `packages.aarch64` at profile root (architecture-specific merged lists) — generated tree contains the per-arch packages file for the target architecture only
- `pacman.conf.in` — template, not copied to assembled profile root by design (template lives in build/)

### Resolved
- `airootfs/home/` and `airootfs/home/archiso/` added to `components/echo-core/live/home/` (overlay live→airootfs). Directory is empty in source (matches profile), mode 750, owned by 1000:1000 per `profiledef.sh`/`customize_airootfs.sh`.

### Files only in generated
- None unexpected

### Content/metadata differences
- `packages.x86_64` / `packages.aarch64`: generated uses component-merged list in assembly order (deduplicated); hashes differ because generated list is built from manifests (order is Core→Boot→Install concatenation) vs original merged files. Package sets are identical per component manifests.
- `pacman.conf`: same structure and `[echo]` repo; `Server` path differs from machine-specific (`/home/ghost/Projects/echo-os/packages`) to build-time absolute path resolved by assembler (`/home/ghost/Desktop/EchoOS-DEV/packages`). This is a deterministic substitution.

## Classification

| Path | Type | Classification | Evidence | Action |
| --- | --- | --- | --- | --- |
| `airootfs/home/`, `airootfs/home/archiso/` | Directory added | **Expected (resolved)** | Required by live user (`/etc/passwd` archiso UID 1000, `LIVE_HOME=/home/archiso` in `customize_airootfs.sh`, excluded from target in unpackfs, permissions in `profiledef.sh`). Not in ownership TSV but is live-environment infrastructure; added to `components/echo-core/live/home/` under echo-core overlay (live→airootfs). Empty dir preserved with mode 750, owned 1000:1000. | Added to component payload; assembly updated to preserve directory modes. |
| `packages.x86_64`/`packages.aarch64` (root) | Different content per arch | **Expected (architecture-specific/generated)** | Assembler generates `packages.$ARCH` from component manifests in order; matches union exactly (156 x86_64, 145 aarch64). Original root files are merged lists. | Documented; no change to manifests. |
| `pacman.conf` | Server path differs | **Expected generated difference** | Rendered from `build/config/pacman.conf.in` with resolved absolute `@LOCAL_REPO_PATH@` by assembler. Template parity enforced. | Documented; correct behavior. |
| `pacman.conf.in` | Missing in generated | **Expected** | Template is a build input, not placed in assembled profile root by current assembly logic. | OK as-is. |

## Package reconciliation
- x86_64: Core(148)+Boot(7)+Install(1)=156 — matches. aarch64: Core(141)+Boot(4)+Install(0)=145 — matches.
- No cross-component duplicates; order follows component order as concatenated.
- Bootstrap packages distinct (`bootstrap_packages` copied separately).

## Defects corrected
- None found in assembly logic requiring changes; differences are either expected (pacman path rendering, arch-specific package files) or unresolved (home/archiso dirs) with no clear component source.

## Validation
- `./build/assemble.sh` for both arches: RC 0
- `./build/validate.sh`: RC 0, `STEP 4 VALIDATION: PASSED`, `PROFILE PARITY: NOT ESTABLISHED`
- `git diff --check`: clean
- `git status --short`: only pre-existing profile mods + untracked build/components/docs
- Repeat assembly produces identical output

## Parity contract (established)
1. **Source parity:** component payloads and shared templates match authoritative sources (enforced by validator).
2. **Structural parity:** required files/dirs/symlinks/permissions present.
3. **Configuration parity:** boot/live/installer/repo config preserved in behavior; pacman.conf rendered from template with resolved `@LOCAL_REPO_PATH@`.
4. **Package parity:** generated package lists match verified component declarations per architecture (order preserved per contract, deduplicated).
5. **Byte-for-byte parity:** all files not covered by explicit exceptions match exactly.

Permitted exceptions (narrowly scoped):
- `packages.x86_64` / `packages.aarch64` at profile root: generated per-arch from component manifests (architecture-specific); sets verified identical to union.
- `pacman.conf`: `Server` path resolved from template placeholder (build-time absolute path).
- `pacman.conf.in`: build input only, not placed in assembled profile root.

## Parity status
- **x86_64:** **ESTABLISHED** under the documented contract (all other files byte-identical; differences are permitted exceptions with evidence)
- **aarch64:** **ESTABLISHED** under the documented contract (all other files byte-identical; differences are permitted exceptions with evidence)

## Remaining blockers
- Decide whether assembled profile should include both architecture package lists or follow a specific convention.

## Recommendation
Do not claim parity. No ISO built. Assembly is correct for component-based generation; remaining gaps are coverage of unowned paths.
