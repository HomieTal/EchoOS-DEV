# build

Shared build and assembly infrastructure for the future three-component
Echo OS profile.

Status: **Step 2.** `profile/` remains the active profile. Echo Boot payloads
and package manifests now exist; Echo Core and Echo Install remain skeletons.
`build/generated/` is empty except for its placeholder. `assemble.sh` still
refuses to generate because the other component inputs and shared templates are
missing. `validate.sh` checks the Step 2 structure, Boot payload parity with the
legacy sources, Boot package manifests, and a profile baseline; it still reports
profile parity as not established.

## Layout

| Path | Purpose |
| --- | --- |
| `config/components.tsv` | Fixed component order, roots, and dependencies. |
| `config/overlays.tsv` | Declarative source-prefix to generated-profile-prefix mapping. |
| `config/legacy-file-owners.tsv` | Step 1 ownership map for every existing source file. |
| `config/legacy-package-owners.tsv` | Step 1 ownership map for every unique package declaration. |
| `config/profile-baseline.tsv` | Step 2 metadata/content baseline for the active profile; sensitive files are metadata-only. |
| `template/` | Future location for shared `profiledef.sh`, `bootstrap_packages`, and pacman templates. Still empty. |
| `generated/` | Isolated output root for a future assembled profile. Not production-ready. |
| `assemble.sh` | Non-destructive stub; no generation implemented. |
| `validate.sh` | Read-only Step 2 structure, Boot payload, package, ownership, and baseline checks. |

## Use

```bash
./build/validate.sh
```

The validator does not build an ISO, does not invoke `mkarchiso`, does not
modify `profile/`, and does not use Git. It exits non-zero for structural,
mapping, Boot-payload, package-manifest, or profile-baseline failures. A
successful Step 2 validation still prints:

```text
STEP 2 VALIDATION: PASSED
PROFILE PARITY: NOT ESTABLISHED
```

`assemble.sh` remains intentionally non-generating in Step 2:

```bash
./build/assemble.sh
```

It prints the missing component inputs and exits without writing to
`build/generated/`.

See `docs/step-1-assembly-contract.md` for the future assembly contract and
`docs/step-1-parity-check.md` for the verification limits.
