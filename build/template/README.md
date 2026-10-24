# build/template

Canonical shared ArchISO templates for assembly.

These templates are the assembly inputs named by
`docs/step-1-assembly-contract.md`. They were introduced from the existing
authoritative `profile/` files without altering content, modes, boot modes,
`file_permissions`, package declarations, or placeholders:

- `profiledef.sh` — copied from `profile/profiledef.sh`.
- `bootstrap_packages` — copied from `profile/bootstrap_packages`.

During the migration window, `build/validate.sh` enforces byte-for-byte parity
between each template and its authoritative source so the two cannot drift.
Assembly reads only these templates; `profile/` remains the read-only legacy
reference. Once assembly generates an isolated profile under
`build/generated/profile/` and parity is proven, the template/source
relationship can be inverted so the active profile is derived from these
templates.

The pacman configuration template lives at `build/config/pacman.conf.in`
(copied from `profile/pacman.conf.in`), per the assembly contract.

No unsupported ArchISO variables may be added. `build/generated/` is the only
allowed output location.
