# Shared Build Template Resolution Report

Status: **resolved** (templates present and parity-checked). Assembly remains
unimplemented by design. `PROFILE PARITY: NOT ESTABLISHED`.

No ISO was built, no profile was generated, and `profile/` was not modified.

## 1. Investigation (read-only)

Inspected:

- `build/template/README.md` — states `build/template/` is the future home for
  shared ArchISO templates, with `profiledef.sh` and `bootstrap_packages`
  derived from `profile/`.
- `build/config/README.md` — declarative build data; points to the assembly
  contract.
- `docs/step-1-assembly-contract.md` — explicitly lists
  `build/config/pacman.conf.in`, `build/template/profiledef.sh`, and
  `build/template/bootstrap_packages` as assembly inputs. It also states the
  active `profile/` is a read-only parity reference and that
  `scripts/render-pacman-conf.sh` must not write to `profile/` during assembly.
- `build/assemble.sh` — preflight checks the three expected paths.
- `scripts/render-pacman-conf.sh` — renders `profile/pacman.conf` in place from
  `profile/pacman.conf.in` (existing direct-build behavior; left unchanged).
- `build/config/legacy-file-owners.tsv` — maps each source as `SHARED`/`BUILD`
  to the expected destination path.
- Git history: `build/template/` has never existed; `profile/profiledef.sh`
  originated from the upstream archiso releng profile and carries project
  modifications (extra `file_permissions` entries, boot modes
  `bios.syslinux` + `uefi.systemd-boot`). `profile/pacman.conf.in` is the
  build-time template with `@LOCAL_REPO_PATH@` and `[echo]`.

Candidate sources were byte-compared against the expected destinations:
none of the destinations existed.

### Source-of-truth decision

Chosen: **Approach A — copy the authoritative file verbatim** to the expected
location, plus validation that enforces byte-for-byte parity with the source.

Rationale:

- The assembly contract and ownership map already name the `build/` paths as
  canonical assembly inputs; the consumers (`build/assemble.sh`) check those
  specific paths.
- `profile/` is designated as the read-only legacy/parity reference, so making
  the assembler read `profile/` directly (approach B) would couple assembly to
  the tree it must not modify and contradict the contract.
- No transformation is required (approach C): `pacman.conf.in` already carries
  its placeholder, and `profiledef.sh`/`bootstrap_packages` are used unchanged.
  Inventing a derivation would risk changing boot modes, permissions, or
  package declarations.
- "Two independent copies" is avoided in practice: the validator fails if the
  template and its source diverge in content or mode. Once assembly generates
  an isolated profile and parity is proven, the relationship can be inverted so
  the active profile is derived from the templates.

## 2. Files changed

| File | Change | Reason |
| --- | --- | --- |
| `build/template/profiledef.sh` | New (verbatim copy of `profile/profiledef.sh`) | Shared profiledef assembly input |
| `build/template/bootstrap_packages` | New (verbatim copy of `profile/bootstrap_packages`) | Shared bootstrap package input |
| `build/config/pacman.conf.in` | New (verbatim copy of `profile/pacman.conf.in`) | Shared pacman template input |
| `build/template/README.md` | Rewritten to record resolved status and parity rule | Replaces stale "directory intentionally empty" statement |
| `build/config/README.md` | Documented `pacman.conf.in` role and parity rule | Keep config docs accurate |
| `build/validate.sh` | Added template files to required inputs; added source/mode parity, regular-file, bootmode, `pacman_conf`, `@LOCAL_REPO_PATH@`, and `[echo]` checks | Verify presence and prevent drift; failure gate unchanged |
| `docs/shared-template-resolution-report.md` | New | This report |

Not changed: `profile/` (byte-for-byte), `components/echo-boot/`,
`components/echo-install/`, `components/echo-core/` payloads and manifests,
`build/assemble.sh`, `scripts/render-pacman-conf.sh`.

## 3. Parity results

| Template | Source | Mode src/dst | SHA-256 (src = dst) |
| --- | --- | --- | --- |
| `build/template/profiledef.sh` | `profile/profiledef.sh` | 644 / 644 | `2ce0c7805aa8ad4451c11ac22b7be73940d17cee4b211a70e87792d654598e8a` |
| `build/template/bootstrap_packages` | `profile/bootstrap_packages` | 644 / 644 | `9e602440a68d69d11908d5f953d96ba3a8e4eb2ec36a47c87d977a70d1bce140` |
| `build/config/pacman.conf.in` | `profile/pacman.conf.in` | 644 / 644 | `68584bcbd35f33ad4de98fb9d59464eed2a39190ea0d1abd8bf8f671bdacb75f` |

- No source file is a symlink; all destinations are regular files.
- Boot modes preserved: `bios.syslinux`, `uefi.systemd-boot`.
- `file_permissions` preserved unchanged (including Calamares/live entries).
- `pacman_conf="pacman.conf"` preserved.
- `bootstrap_packages` still declares exactly `arch-install-scripts` and `base`.
- `@LOCAL_REPO_PATH@` and `[echo]` preserved in the pacman template.

## 4. Validation

```bash
./build/validate.sh
# exit code: 0
# STEP 4 VALIDATION: PASSED
# PROFILE PARITY: NOT ESTABLISHED
```

All prior Boot/Install/Core checks still pass; the new checks report
`OK shared templates match authoritative sources`.

Failure-path test in an isolated copy (`/tmp/echo-tpltest`, not the repository):
appending a line to `build/template/profiledef.sh` produced

```text
FAIL shared template differs from source: build/template/profiledef.sh != profile/profiledef.sh
STEP 4 VALIDATION: FAILED (4 failure(s))
RC: 1
```

The additional failures in that disposable copy were expected because
`build/repo/` and `packages/` were not copied. The key result is that a genuine
template drift produces a nonzero exit; the failure gate was not weakened.

Other commands:

```bash
git diff --check      # clean, RC 0
git status --short    # only pre-existing profile changes and untracked build/, components/, docs/
git diff -- profile/  # pre-existing modifications only; no change from this task
```

`build/assemble.sh` re-inspected (not modified): it now reports all inputs
present and still refuses with `ASSEMBLY NOT IMPLEMENTED`, exit code **2**,
writing nothing.

## 5. Remaining blockers / next step

- `build/assemble.sh` remains a non-generating stub (Step 5 work).
- No generated profile exists; profile parity is not established.
- `scripts/render-pacman-conf.sh` still renders `profile/pacman.conf` in place;
  Step 5 must adapt rendering to write only under `build/generated/profile/`.

## 6. Confirmation

- `profile/` preserved byte-for-byte (mtimes/hashes unchanged; validator
  baseline check passes).
- `components/echo-boot/`, `components/echo-install/`, and Echo Core payloads
  and manifests unchanged.
- No ISO built and no generated profile produced.
