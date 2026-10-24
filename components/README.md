# Echo OS component model

Status: **Step 2 — Echo Boot populated; Core and Install remain skeletons.**
`profile/` remains the single active ArchISO profile and the only source of
truth for the working ISO. Echo Boot has real component inputs; Echo Core and
Echo Install do not yet have payloads. No assembly has been run, and profile
parity is **not established**.

## Components

| Component | Primary responsibility | Current profile files | Current packages |
| --- | --- | ---: | ---: |
| `echo-boot` | Live ISO boot menus, live initramfs configuration, bootloaders and EFI assets | 15 | 8 |
| `echo-install` | Calamares configuration, its live-only policy, and the Calamares package recipe | 21 | 1 |
| `echo-core` | Base system, kernel/firmware, XFCE, LightDM, services, networking, live account and rescue tooling | 66 | 150 |
| Shared build infrastructure | ArchISO profile definition, pacman configuration, package-list generation, local repository, build/validation scripts | 16 | 0 |

The file counts include profile files and owned build inputs. The complete
per-file and per-package mapping is in:

- `build/config/legacy-file-owners.tsv`
- `build/config/legacy-package-owners.tsv`

Those TSVs are Step 1 ownership records, not assembly inputs.

## Dependencies

- `echo-core` is the base layer. It has no component dependency.
- `echo-boot` depends on `echo-core` for the kernel, firmware, initramfs tooling,
  filesystem tools, and the live root that consumes its boot menus.
- `echo-install` depends on `echo-core` for the live runtime and on `echo-boot`
  for the target bootloader packages and policy. The Calamares
  `bootloader.conf` remains installer-owned; it consumes Boot policy rather
  than duplicating it.
- Shared build infrastructure provides ArchISO assembly and the generated
  `profiledef.sh`, `pacman.conf`, and package lists. It does not own component
  configuration content.

The declarative dependency order is in `build/config/components.tsv`.

## Ownership rules

1. A file has one primary owner. Cross-component use is expressed as a
   dependency, not by copying the file into two components.
2. A package has one primary owner per architecture. Packages needed by another
   component are consumed through that owner's manifest.
3. Component overlays are additive. There is no "last component wins" rule. Any
   duplicate destination path is an assembly error, even if the contents are
   identical.
4. The current `profile/` is not modified, moved, or overwritten during Step 2.
   Assembly must read it, never write it, and write only under
   `build/generated/`.
5. `profile/airootfs/etc/calamares/modules/unpackfs/exclude-list.txt` is the
   current live/target boundary. It stays installer-owned until a replacement
   is deliberately designed. Placing a file in a live overlay does **not**
   automatically exclude it from the target.

## Scope labels

`build/config/legacy-file-owners.tsv` uses these labels:

| Label | Meaning |
| --- | --- |
| `COMMON` | Delivered to the live root and currently retained in the installed target. |
| `LIVE-EXCLUDED` | Delivered to the live root and explicitly excluded from the target by the current Calamares exclude list. |
| `LIVE-INTENDED` | Live-oriented content that is **currently not excluded** from the target. This records the existing leak; it is not a Step 1 behavior change. |
| `INSTALL-LIVE` | Calamares or its live-only support files. |
| `BOOT-LIVE` | Live ISO boot assets used by the current boot modes. |
| `BOOT-INACTIVE` | Boot assets retained for a boot mode not selected by `profiledef.sh`. |
| `BUILD` | Build input or build documentation. |
| `GENERATED` | File to be produced by assembly rather than copied. |
| `ARTIFACT` | Built package or repository artifact, not a source of truth. |

## Shared build infrastructure

The shared layer owns the existing `build.sh`, `scripts/render-pacman-conf.sh`,
`profile/profiledef.sh`, `profile/pacman.conf.in`, package-list assembly,
`packages/PKGBUILD` repository mechanics, and the local repository. It must not
become a second source for component configuration.

The future assembly and parity contracts are documented in:

- `docs/step-1-component-map.md`
- `docs/step-1-assembly-contract.md`
- `docs/step-1-parity-check.md`

## Deliberately out of scope for Step 2

- Migrating Echo Install or Echo Core, or activating the assembled profile.
- Overwriting the legacy package lists or replacing `profile/` as the active
  profile.
- Changing XFCE, LightDM, GRUB, systemd-boot, Calamares, boot modes, kernel
  parameters, initramfs behavior, or package selections.
- Implementing KDE, rEFInd boot changes, Echo branding, animal codenames, or
  Aira.
- Building an ISO or testing boot/installation.
