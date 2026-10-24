# build/config

Configuration records for component ownership, profile preservation, and
future assembly. Step 2 adds the Boot component inputs and the profile baseline.

These files are declarative data, not ArchISO configuration:

- `components.tsv` defines component order, roots, and dependencies.
- `overlays.tsv` defines how component source prefixes map into the generated
  ArchISO profile. Overlays are additive; duplicate destination paths are
  errors.
- `legacy-file-owners.tsv` classifies every existing source file with one
  owner, one current live/target scope, one proposed future source path, and one
  proposed profile destination.
- `legacy-package-owners.tsv` classifies every unique package declaration with
  one owner, current scope, architecture presence, and rationale.
- `pacman.conf.in` is the shared build-time pacman template (copied verbatim
  from `profile/pacman.conf.in`); it keeps the `@LOCAL_REPO_PATH@` placeholder
  and the `[echo]` repository declaration. `build/validate.sh` enforces
  byte-for-byte parity with the authoritative source.
- `profile-baseline.tsv` records the active profile's path/type/mode/size and,
  for non-sensitive files, a content hash. It is used only to prove that Step 2
  did not change `profile/`. Sensitive files are metadata-only and are never
  hashed or copied into documentation.

`components.tsv` and `overlays.tsv` are intended assembly inputs. The two
`legacy-*` TSVs are transitional Step 1 parity records; they must not become a
second package list or a competing source of configuration content. The
component package manifests are the first real assembly inputs; only Echo Boot
has them after Step 2.

The assembly contract is in `docs/step-1-assembly-contract.md`.
