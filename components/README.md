# Echo OS component model

Status: **Active.** Echo OS is assembled from four independent components by
`build/assemble.sh`. The components are the source of truth; the assembled
profile in `build/generated/profile` is the input to `mkarchiso`. The legacy
`profile/` tree is retained as a read-only parity reference.

## Components

| Component | Primary responsibility | Assembly order |
| --- | --- | ---: |
| `echo-core` | Base system, kernel/firmware, initramfs tooling, filesystems, networking, services, live account and rescue tooling | 10 |
| `echo-boot` | Live boot menus, rEFInd/EFI assets, Syslinux, live initramfs config and boot packages | 20 |
| `echo-desktop` | KDE Plasma 6, KWin, SDDM/Wayland, Echo theme, wallpaper, desktop apps, live autologin | 30 |
| `echo-install` | Calamares, installer branding, live installer launcher, installed-system service and boot policy | 40 |
| Shared build infrastructure | ArchISO profile definition, pacman config, package-list assembly, local repository, build/validation scripts | n/a |

## Dependencies

- `echo-core` is the base layer and has no component dependency.
- `echo-boot`, `echo-desktop`, and `echo-install` depend on `echo-core`.
- `echo-install` also depends on `echo-boot` and `echo-desktop`.
- Dependencies must be ordered before their dependants in
  `build/config/components.tsv`; the assembler and validator enforce this.

## Ownership rules

1. A file has one primary owner. Cross-component use is expressed as a
   dependency, not by copying the file into two components.
2. A package has one primary owner per architecture. Duplicate package
   declarations across components are an assembly error.
3. Component overlays are additive. There is no "last component wins" rule. Any
   duplicate destination path is an assembly error, even if the contents are
   identical.
4. `profile/` is a read-only reference. Assembly reads components and writes
   only under `build/generated/`.
5. The Calamares `unpackfs` exclude list is the authoritative live/target
   boundary. Placing a file in a `live/` overlay does not automatically exclude
   it from the installed target.
6. Desktop packages and configuration belong only to `echo-desktop`. Core,
   Boot, and Install must not declare or configure a desktop session.

## Component layout

Each component provides:

```text
README.md                       ownership and contract
packages/packages.x86_64        architecture package manifest
packages/packages.aarch64       architecture package manifest
<overlay directories>           payload mapped by build/config/overlays.tsv
```

The assembler merges overlay directories and package manifests in component
order. The validator assembles both architectures in temporary directories and
checks the contracts without touching the published generated profile.

## Assembled profile

```text
build/generated/profile/        active mkarchiso profile (x86_64)
build/generated/profile-aarch64/ validation/assembly output for ARM
build/generated/assembly-manifest.tsv
```

`build.sh` runs `build/assemble.sh` and then `mkarchiso`. The generated profile
is disposable and must not be edited by hand.

## Scope labels

`build/config/legacy-file-owners.tsv` records the original ownership mapping
used during the migration:

| Label | Meaning |
| --- | --- |
| `COMMON` | Delivered to the live root and currently retained in the installed target. |
| `LIVE-EXCLUDED` | Delivered to the live root and explicitly excluded from the target by the Calamares exclude list. |
| `LIVE-INTENDED` | Live-oriented content that is currently not excluded from the target. |
| `INSTALL-LIVE` | Calamares or its live-only support files. |
| `BOOT-LIVE` | Live ISO boot assets used by the current boot modes. |
| `BOOT-INACTIVE` | Boot assets retained for a boot mode not selected by `profiledef.sh`. |
| `BUILD` | Build input or build documentation. |
| `GENERATED` | File produced by assembly rather than copied. |
| `ARTIFACT` | Built package or repository artifact, not a source of truth. |

## Validation

Run `./build/validate.sh`. It checks component structure, order, dependencies,
overlay safety, package ownership and duplicates, the SDDM/Plasma desktop
contract, the Calamares installer contract, the live/target boundary, and
assembly for both architectures. A passing run prints
`ECHO OS VALIDATION: PASSED`.

Validation does not build or boot an ISO. Use `./build.sh` for an ISO and a
disposable UEFI VM for boot verification.
