# echo-boot

Status: **Active.** Echo Boot is a real assembly component merged into
`build/generated/profile` by `build/assemble.sh`. It owns live boot menus, EFI
assets, and boot packages. Installed-system bootloader policy belongs to
`echo-install`.

## Responsibilities

- **UEFI live boot:** rEFInd is the user-visible UEFI boot menu on the live
  medium. ArchISO's `uefi.systemd-boot` boot mode still stages the ESP; the
  project replaces the systemd-boot loader binary with rEFInd, so
  `EFI/BOOT/BOOTx64.EFI` is rEFInd.
- **Live EFI entries:** `EFI/BOOT/refind.conf` provides the Echo OS live
  entry, the accessibility entry, and the menu tools.
- **ArchISO fallback entries:** `efiboot/loader/` retains systemd-boot-style
  entries for the staged boot mode.
- **BIOS live boot:** Syslinux configuration and artwork under `syslinux/`.
- **Kernel/initramfs config:** ArchISO mkinitcpio drop-in
  (`/etc/mkinitcpio.conf.d/archiso.conf`).
- **Boot artwork:** rEFInd icons and fonts, Syslinux splash.
- **Boot theme:** the `EFI/BOOT/themes/wolfe/` rEFInd theme (Wolfe
  adaptation, MIT — see that directory's README.md and LICENSE), applied by
  every shipped rEFInd configuration via `include themes/wolfe/theme.conf`.
- **Boot-related packages:** Declared in `packages/packages.x86_64` and
  `packages/packages.aarch64`.

Echo Boot does **not** own the kernel, initramfs tooling, firmware, or live
root; those are Core. It does not own installed-system bootloader selection;
that is the Calamares `refindboot` module in Echo Install.

## Layout

```text
config/EFI/                    EFI assets as staged for the ISO
config/EFI/BOOT/themes/wolfe/  rEFInd boot theme (Wolfe adaptation)
config/efi/                    rEFInd loader fallback tree
config/boot/                   rEFInd loader, config, and bootmount helper
config/efiboot/loader/         ArchISO UEFI loader entries
config/loader/                 top-level loader entries
config/fonts/, config/icons/   rEFInd menu artwork
config/refind.conf             top-level rEFInd configuration
config/refind_x64.efi          rEFInd loader
config/syslinux/               BIOS Syslinux configuration and splash
config/grub/                   retained inactive GRUB assets
config/initramfs/archiso.conf  ArchISO mkinitcpio drop-in
config/airootfs/               boot payload delivered into the live root
```

## Boot theme

`config/EFI/BOOT/themes/wolfe/` is the Wolfe rEFInd theme adapted for
Echo OS (MIT license preserved in its `LICENSE`). `refind.conf` includes
`themes/wolfe/theme.conf`; directives after the include override theme
defaults (`showtools` re-adds `firmware`). Icons missing from the theme
set fall back to the standard `EFI/BOOT/icons/` directory.

Per-release assets (animal artwork, background, wordmark, accent colour,
release name) live in `themes/wolfe/release/` and are the only things that
change between animal releases; see `themes/wolfe/release/release.conf`.
`build.sh` syncs `themes/` into both the ISO 9660 `EFI/BOOT` tree and the
ESP image (`efiboot.img`) together with `refind.conf`, `echoos.conf`,
`fonts/` and `icons/`.

## Overlays

From `build/config/overlays.tsv`:

| Source prefix | Generated profile destination |
| --- | --- |
| `config/efiboot` | `efiboot` |
| `config/syslinux` | `syslinux` |
| `config/grub` | `grub` |
| `config/initramfs` | `airootfs/etc/mkinitcpio.conf.d` |
| `config/EFI` | `EFI` |
| `config/efi` | `efi` |
| `config/boot` | `boot` |
| `config/loader` | `loader` |
| `config/fonts` | `fonts` |
| `config/icons` | `icons` |
| `config/refind.conf` | `refind.conf` |
| `config/refind_x64.efi` | `refind_x64.efi` |
| `config/airootfs` | `airootfs` |

Overlay order follows `components.tsv`: Core (10), Boot (20), Desktop (30),
Installer (40).

## Boot modes

`build/template/profiledef.sh` selects both boot paths for x86_64 builds
(and UEFI only on aarch64, where syslinux does not exist):

```bash
if [ "$(uname -m)" = "x86_64" ]; then
    bootmodes=('bios.syslinux' 'uefi.systemd-boot')
else
    bootmodes=('uefi.systemd-boot')
fi
```

`uefi.systemd-boot` is the ArchISO staging mechanism. Echo OS replaces the
staged loader with rEFInd; the boot mode name is not a statement that
systemd-boot is the visible menu. BIOS remains Syslinux. rEFInd is not an
ArchISO boot mode.

### Legacy BIOS path (universal boot compatibility)

`config/syslinux/` is overlaid to `syslinux/` in the assembled profile and
mkarchiso's `bios.syslinux` mode produces, in one hybrid ISO:

- an El Torito **BIOS boot catalog entry** (`isolinux.bin`), and
- **isohdpfx MBR boot code** so BIOS USB boots work on the same image.

`syslinux.cfg` / `archiso_*.cfg` are Echo OS branded ("Echo OS install
medium (x86_64, BIOS)", `MENU TITLE Echo OS`); `splash.png` is the Echo OS
branded menu background. The kernel/initramfs paths, `%INSTALL_DIR%`,
`%ARCHISO_UUID%` and `%KERNEL_PARAMS%` templating are the stock archiso
contract and are rendered by mkarchiso. The BIOS path launches the same
live system as the UEFI path; it depends on no EFI executable.

`build.sh` refreshes `work/iso/EFI/BOOT/refind.conf` from the assembled profile
when a staging tree already exists, because mkarchiso does not process
`profile/EFI/BOOT` as a profile source. Keep that sync step in mind when
changing `refind.conf`.

## Packages

`packages/packages.x86_64`:

```text
edk2-shell
efibootmgr
memtest86+
memtest86+-efi
refind
syslinux
```

`packages/packages.aarch64`:

```text
edk2-shell
efibootmgr
stubble
```

`refind` is present on x86_64 because the live UEFI menu and the installed
target both use rEFInd. Boot does not duplicate the kernel package; that is
declared by Core.

## Dependencies

- **SPD Core (echo-core):** Boot consumes the kernel, firmware, initramfs tooling, and
  live root. Core owns the `mkinitcpio-archiso` package.
- **Echo Install:** The installed-system bootloader is written by Calamares
  (`shellprocess-refindboot.conf` and `echoos-refindconf-write`). Echo Boot
  does not enable or configure the target bootloader.
- **Shared:** `build/template/profiledef.sh` defines boot modes and ISO
  metadata; `build/assemble.sh` merges the overlays.

## Validation

`./build/validate.sh` assembles both architectures into temporary directories.
It verifies component order, overlay sources, package manifests, and that the
assembled profile covers the legacy tree.

## Out of scope

- Kernel, firmware, and initramfs package ownership (Core).
- Desktop session and display manager (Desktop).
- Installed-system bootloader execution (Installer).
- Changing the ArchISO boot-mode contract without a separate reviewed change.
