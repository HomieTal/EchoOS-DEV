# echo-boot

Owns **rEFInd, EFI payloads, and live boot menus**. The graphical desktop does
not affect this component; boot configuration is independent of
`echo-desktop`.

## Responsibilities

- rEFInd payload used for UEFI live boot: `config/EFI/BOOT/` (binary, menu
  config, icons, fonts).
- BIOS/legacy menus: `config/syslinux/` (Syslinux config + splash).
- systemd-boot metadata used by mkarchiso while building the ISO:
  `config/efiboot/loader/`.
- ArchISO initramfs drop-in: `config/initramfs/archiso.conf`.
- GRUB assets for BIOS installs of the target system: `config/grub/`
  (staged on the ISO; `grub-install` runs chrooted from the target).
- Boot-owned packages: `refind`, `syslinux`, `edk2-shell`, `efibootmgr`,
  `memtest86+`, `memtest86+-efi`, `grub`.

The installed system's bootloader is installed by Calamares
(`shellprocess@refindboot`, owned by `echo-install`): rEFInd into the ESP on
UEFI installs, GRUB into the MBR on BIOS installs. Both run from the live
root, which ships `refind` and `grub`.

## Overlays

See `build/config/overlays.tsv`. Boot contributes:

| Source | Generated profile destination |
| --- | --- |
| `config/efiboot` | `efiboot` |
| `config/syslinux` | `syslinux` |
| `config/grub` | `grub` |
| `config/initramfs` | `airootfs/etc/mkinitcpio.conf.d` |
| `config/EFI` | `EFI` (rEFInd payload used by the ISO repack step) |

## ISO assembly

mkarchiso's `uefi.systemd-boot` boot mode always writes systemd-boot to
`\EFI\BOOT\BOOTX64.EFI` and has no hook for replacing the ESP payload. Echo OS
therefore builds the ISO in two steps (`build.sh`):

1. `mkarchiso` produces the ISO staging tree (`work/iso`).
2. `scripts/refind-iso.sh` replaces `EFI/BOOT` with this component's rEFInd
   payload, builds a fresh FAT ESP image (rEFInd +
   `arch/boot/x86_64/{vmlinuz,initramfs}`), and repacks the ISO with the same
   El Torito/GPT options mkarchiso uses.

This removes the old dependency on a manually pre-seeded `work/iso` tree: the
rEFInd ISO is reproducible from the assembled profile alone.

## Boot modes

`profiledef.sh` keeps `bios.syslinux` and `uefi.systemd-boot` (the latter is
only the mkarchiso mechanism; the final ESP payload is rEFInd).

## Validation

Boot-specific checks are part of the build: `refind-iso.sh` fails if the rEFInd
payload, syslinux files, kernel, or initramfs are missing. The final ISO is
boot-tested in a UEFI VM; see the Step 8 report.
