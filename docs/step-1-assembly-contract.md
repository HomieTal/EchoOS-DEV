# Step 1 assembly contract

Status: **design only; Echo Boot inputs populated in Step 2.** `build/assemble.sh`
remains a non-generating stub. Nothing is assembled yet, and profile parity is
**not established**.

This contract describes how a future assembler will read the three components
and produce an isolated ArchISO profile under `build/generated/` without
modifying `profile/`.

## 1. Inputs

Assembly reads only declarative inputs and component trees:

```text
build/config/components.tsv       component order, roots, dependencies
build/config/overlays.tsv         source-prefix -> profile-prefix mapping
components/echo-core/             Core payloads (future)
components/echo-boot/             Boot payloads (Step 2 populated)
components/echo-install/          Installer payloads (future)
build/config/pacman.conf.in       shared pacman template
build/template/profiledef.sh      shared profiledef template (future)
build/template/bootstrap_packages shared bootstrap list (future)
```

The current `profile/` is a read-only parity reference, never an assembly
output.

`legacy-file-owners.tsv` and `legacy-package-owners.tsv` are Step 1 ownership
records. They are used by validation, not as replacement package/config
sources.

## 2. Component definitions and order

`build/config/components.tsv` defines a fixed, deterministic order:

```text
10 echo-core      requires: -
20 echo-boot      requires: echo-core
30 echo-install   requires: echo-core,echo-boot
```

Assembly must:

1. Read the file in numeric order.
2. Require each component root and its `README.md`.
3. Validate every `requires` entry is a known component with a lower order.
4. Refuse unknown components, duplicate order values, cycles, or missing roots.
5. Never resolve overlay precedence by "later component wins".

The dependency graph is for validation and documentation. It does not change
package sets or make one component's config override another's.

## 3. Package resolution

Each component provides both files:

```text
components/<component>/packages/packages.x86_64
components/<component>/packages/packages.aarch64
```

Format:

- UTF-8 text, one package name per line.
- Blank lines and lines whose first non-blank character is `#` are ignored.
- Leading/trailing whitespace is trimmed.
- Inline comments, shell expansion, globs, and architecture suffixes are not
  supported.
- A package name must match the existing allowed character set used by pacman
  package names: ASCII letters, digits, `@`, `.`, `_`, `+`, and `-`.
- Both architecture files must exist. An empty file is explicit and valid only
  when the component has no packages for that architecture.

Resolution rules:

1. For each architecture, read manifests in component order.
2. Reject duplicate occurrences of the same package across components.
3. Build a deterministic list with `LC_ALL=C sort -u`.
4. In parity mode, compare the resulting set with the legacy list for that
   architecture. Missing and extra packages are both hard errors. The current
   expected counts are 156 for x86_64 and 145 for aarch64, but the comparison is
   by set, not by hard-coded count alone.
5. Write `build/generated/profile/packages.<arch>` only after all checks pass.

Package **set** parity is required. Line order may differ because it is
deterministically sorted; this does not change the selected packages. Package
manifests describe the live installation set. They do **not** define target
exclusions; the Calamares exclude list remains the target boundary.

## 4. Overlay merge

`build/config/overlays.tsv` maps component source prefixes to profile-relative
destinations:

| Component | Source prefix | Destination prefix |
| --- | --- | --- |
| `echo-core` | `airootfs/` | `airootfs/` |
| `echo-core` | `live/` | `airootfs/` |
| `echo-boot` | `config/efiboot/` | `efiboot/` |
| `echo-boot` | `config/syslinux/` | `syslinux/` |
| `echo-boot` | `config/grub/` | `grub/` |
| `echo-boot` | `config/initramfs/` | `airootfs/etc/mkinitcpio.conf.d/` |
| `echo-install` | `calamares/` | `airootfs/etc/calamares/` |
| `echo-install` | `config/live/` | `airootfs/etc/` |

The `live/` prefix means live-oriented payload. It does **not** imply automatic
target exclusion. Exclusion remains an explicit Installer-owned policy so the
current 25-entry exclude list can be preserved during parity.

Assembly must:

1. Enumerate every source file, directory, and symlink under each existing
   source prefix.
2. Compute the destination as `destination_prefix + relative_path`.
3. Reject absolute paths, empty relative paths, `..` traversal, and
   destinations outside the generated profile root.
4. Detect duplicate destination paths across all overlays. Exact duplicates are
   hard errors even when contents are byte-identical. Later components do not
   overwrite earlier ones.
5. Treat missing declared source prefixes as errors once a component is marked
   complete. During Steps 1-2, the missing Core/Install inputs are why assembly
   refuses.
6. Copy with a mode that preserves directory structure, symlinks, modes,
   ownership where the build privileges allow it, timestamps, and extended
   attributes. `cp -a` is the baseline; the assembler must verify the result
   rather than assume success.

## 5. Conflict detection and preflight

Preflight must fail before writing output if any of these hold:

- A component root, README, package manifest, overlay prefix, or required
  shared template is missing.
- A component dependency is unknown or resolved out of order.
- A package is duplicated, malformed, missing, or extra relative to the parity
  baseline.
- A destination path is duplicated.
- A destination escapes the generated profile root.
- `build/generated/profile` already exists, or `build/generated` contains a
  non-placeholder entry.
- The source profile changed while assembly was running.
- An unsupported special file type is found (the current profile has only
  regular files, directories, and symlinks).

No destructive cleanup is part of this contract. A future implementation may
stage into a uniquely named child of `build/generated/` and remove only that
staging directory on failure. It must never remove or rewrite `profile/`.

## 6. Generated profile

The isolated output root is:

```text
build/generated/profile/
```

Only this path is an ArchISO profile candidate. `build/generated/` itself is not
production-ready and is never the active build input automatically.

Assembly outputs:

- Overlay trees at their profile-relative destinations.
- `packages.x86_64` and `packages.aarch64` resolved from component manifests.
- `pacman.conf` rendered from `build/config/pacman.conf.in`, with the local
  repository path made absolute for the generated location.
- `profiledef.sh` from the shared template, preserving existing ArchISO
  variables and the current boot-mode selection.
- `bootstrap_packages` from the shared template.
- An assembly manifest containing generated paths, modes, and symlink targets.

The current `scripts/render-pacman-conf.sh` renders `profile/pacman.conf` in
place. Assembly must not use that behavior; rendering must be adapted to write
only the generated profile.

## 7. ArchISO compatibility

The contract uses only existing ArchISO fields already present in
`profile/profiledef.sh`:

- `iso_name`, `iso_label`, `iso_publisher`, `iso_application`, `iso_version`
- `install_dir`, `bootmodes`, `pacman_conf`
- `airootfs_image_type`, `airootfs_image_tool_options`
- `bootstrap_tarball_compression`, `kernel_params_aarch64`
- `file_permissions`

No new ArchISO variables or config fields are invented. The current boot modes
remain `bios.syslinux` and `uefi.systemd-boot`. GRUB assets remain inactive; no
rEFInd boot mode is added. Existing Calamares module fields are not extended.

`profiledef.sh` remains a shared template so Boot can own boot-mode policy
without creating a second profile definition. `file_permissions` remains shared
for the same reason.

## 8. Source immutability

Assembly must not:

- Write to `profile/`.
- Move or delete existing files.
- Run Git.
- Call `mkarchiso`.
- Rebuild or boot an ISO.

Before assembly, record a metadata snapshot of the source tree (paths, types,
modes, sizes, symlink targets). After assembly, re-check it. Content parity
checks may hash files in memory, but must never print or store credential
material from `/etc/shadow`, `/etc/gshadow`, or `customize_airootfs.sh`.

## 9. Parity gate

A successful assembly is not automatically "parity established". Parity
requires:

1. Complete component manifests and payloads.
2. Package set equality per architecture.
3. Exact overlay destination coverage against the legacy file map.
4. Generated tree comparison with `profile/` for regular files, symlinks,
   modes, and file types.
5. Explicit confirmation that the 25-entry Calamares exclude list is unchanged
   in behavior, including its five stale entries.
6. `PROFILE PARITY: ESTABLISHED` produced by a complete check, not by the Step 1
   validator.

Steps 1-2 still satisfy none of the generated-tree requirements, so the current
result remains:

```text
PROFILE PARITY: NOT ESTABLISHED
```
