# Step 1 parity check

Status: **PROFILE PARITY: NOT ESTABLISHED**

This document records what the Step 1 validation actually proves and what it
does not. The Step 2 update populated Echo Boot, but no generated profile exists
to compare with `profile/`, so the parity conclusion is unchanged.

## How to run

```bash
./build/validate.sh
```

The validator is read-only with respect to the repository. It does not use Git,
does not run `mkarchiso`, does not build or boot an ISO, and does not write to
`build/generated/`. It creates and removes only its own temporary directory.

`./build/assemble.sh` is a non-generating stub. It refuses because the component
payloads and package manifests do not exist yet; it never removes an existing
generated directory.

## Verified by Step 1 validation

| Check | Result |
| --- | --- |
| Required component and build directories exist | Verified |
| Component READMEs and shared documentation exist | Verified |
| Every current profile file/symlink has exactly one ownership row | Verified: 106/106 |
| Every package in both legacy lists has exactly one ownership row | Verified: x86_64 156/156, aarch64 145/145, 159 unique |
| Package rows carry valid architecture flags | Verified |
| Proposed future source paths are unique | Verified |
| Proposed generated destinations are unique | Verified |
| Direct-copy destinations resolve through `overlays.tsv` | Verified for the Step 1 map |
| Component order and declared dependencies are valid | Verified |
| No component payload files exist beyond README/placeholders | Verified |
| No generated profile exists under `build/generated/` | Verified |
| Legacy `profile/` inputs remain present | Verified |
| No Git command, ISO build, or boot/install test was performed | Verified |

Related earlier checks recorded in the Phase 1 report:

- All 18 Calamares files used by `settings.conf` exist in the installed
  Calamares 3.4.2 module set.
- Installed `mkarchiso` supports `bios.syslinux`, `uefi.systemd-boot`, and
  `uefi.grub`; the profile selects only the first two.
- The current 25-entry exclude list has five stale paths; those are recorded but
  unchanged.
- The target is built by copying the live root and applying a file-level exclude
  list. No package is removed as a package, so all 159 packages are currently
  present in the target. `calamares`, `livecd-sounds`, and
  `mkinitcpio-archiso` are intended live-only, but their package payloads are
  not fully excluded; this is recorded, not changed.

## Explicitly not verified

The following are **not** established and must not be described as parity:

- That the three component payloads, once populated, reproduce `profile/`.
- That component package manifests reproduce the legacy package sets. No
  manifests exist yet.
- That overlay merge order and conflict handling produce the same tree.
- That file contents, symlink targets, modes, ownership, timestamps, or extended
  attributes match.
- That the generated profile has the same package selection.
- That the Calamares exclude list still produces the same live/target boundary.
- That the ISO builds, boots, logs in, starts LightDM/XFCE, or installs.
- That the target boots with GRUB or systemd-boot.

The current ownership map proves **coverage and non-ambiguity**, not behavioral
or content parity.

## Why parity is not established

1. `components/echo-boot/` now has boot payloads, but
   `components/echo-install/` and `components/echo-core/` still contain no
   configuration or package payloads.
2. Only the Echo Boot `packages.x86_64` and `packages.aarch64` manifests exist;
   no full component package set exists.
3. No shared `profiledef.sh`, package-list, or pacman template has been
   introduced under `build/template/` or `build/config/`.
4. `build/generated/profile/` does not exist. There is nothing to compare.
5. Assembly is a stub by design, so no generated tree or package list can be
   inspected.
6. No complete generated-vs-legacy comparison has been performed.

A successful Step 2 validator run therefore ends with:

```text
PROFILE PARITY: NOT ESTABLISHED
```

Reason: Echo Boot is populated, but Echo Core/Echo Install inputs are incomplete
and no generated profile exists for a meaningful generated-vs-legacy comparison.

## Future parity procedure

Only after the skeleton and assembly contract are reviewed:

1. Populate component payloads in reviewed increments, keeping `profile/` as the
   read-only reference.
2. Add complete per-architecture package manifests. Do not commit a partial
   manifest; missing and extra packages are both assembly errors.
3. Update the validator for the payload stage, remove the "no payload" Step 1
   assertion, and retain duplicate-destination, package-set, and overlay checks.
4. Implement the assembler according to `docs/step-1-assembly-contract.md`.
5. Generate only under `build/generated/profile/`; never write to `profile/`.
6. Compare:
   - package sets per architecture;
   - every generated file against the legacy file map;
   - regular-file contents, symlink targets, and file types;
   - modes and ownership (and xattrs where supported);
   - the exact behavior of the 25-entry exclude list, including stale entries.
7. Report content-hash mismatches by path only. Never print or store credential
   material from `/etc/shadow`, `/etc/gshadow`, or
   `customize_airootfs.sh`.
8. Only after all checks pass may a result say
   `PROFILE PARITY: ESTABLISHED`.

Boot and installation tests remain separate from file/package parity. They are
out of scope for Step 1 and must not be inferred from a successful assembly.

## Source preservation

No existing profile file was moved, deleted, or overwritten while creating this
skeleton. No Git operation was used. The existing working-tree state, including
the live-login fix and the Phase 1 report, remains in place.

No content checksum baseline was written for sensitive files. Step 1 validation
checks presence, ownership coverage, and proposed destinations only.
