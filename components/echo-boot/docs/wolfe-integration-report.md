# Echo Boot — Wolfe theme integration report

Date: 2026-11-04 · Component: `components/echo-boot` only
Backup: `backups/2026-11-03-pre-wolfe-echo-boot/`

## 1. What was integrated

The downloaded `refind-wolfe-main.zip` (Wolfe rEFInd theme, MIT) is now the
visual foundation of Echo Boot. It ships in the component at:

```text
components/echo-boot/config/EFI/BOOT/themes/wolfe/
├── LICENSE                  upstream MIT license, preserved verbatim
├── README.md                provenance, adaptation notes, release procedure
├── theme.conf               upstream theme config, paths adapted
├── selection_big.png        upstream artwork (144×144), unmodified
├── selection_small.png      upstream artwork (64×64), unmodified
├── icons/                   29 upstream icons unmodified
│   ├── os_echo.png          NEW — Echo "e" mark, Wolfe visual language
│   └── func_firmware.png    NEW — gear glyph for the firmware tool
└── release/                 the ONLY directory that changes per release
    ├── background.png       release background (see §2)
    └── release.conf         release name, accent colour, artwork source
```

Total 38 files, 332 KB (the ESP image is a fixed 264 MiB — ample).

`build.sh` syncs `themes/` into both the ISO 9660 `EFI/BOOT/` tree and the
ESP image (`efiboot.img`), exactly like `refind.conf`, `echoos.conf`,
`fonts/` and `icons/` already were. All four `refind.conf` copies in the
component (top-level, `EFI/BOOT`, `EFI/refind`, `airootfs/EFI/BOOT`) are
byte-identical and contain:

```text
scanfor manual,internal,external,optical   ← automatic EFI entry discovery
include themes/wolfe/theme.conf            ← theme applied to every menu
showtools shutdown, reboot, firmware       ← overrides the theme's default
menuentry "Echo OS — Live Environment"     … icon os_echo.png
menuentry "Echo OS — Live Environment (Accessibility)"  … accessibility=on
```

## 2. Background and branding

Per instruction, the animal artwork from the zip is used **verbatim**: the
upstream `background.png`'s artwork is pixel-identical in
`release/background.png` (verified: 0 differing pixels right of x=1200).
The only change is the wordmark region (x 824–1094, y 318–395), where the
upstream theme-owner wordmark was replaced with **"Echo OS"** in the same
position, colour (`#E8E8E8`) and soft-shadow style (`#211360`), satisfying
the no-external-branding requirement while preserving the theme's design.
The upstream licence/attribution notices are preserved in the theme
directory (required and sufficient; display branding is not shown).

## 3. Future animal releases

Only `themes/wolfe/release/` changes between releases:

1. Replace `release/background.png` (1920×1080; flat accent, release name
   centred at ≈(960, 356), animal artwork anchored bottom-right).
2. Update `release/release.conf` (name, date, accent, artwork source).
3. Leave `theme.conf`, `selection_*.png`, `icons/` and all `refind.conf`
   files untouched. Past releases stay in git history, not on the ESP.

## 4. Validation results

| Check | Result |
| --- | --- |
| `build/assemble.sh` x86_64 + aarch64 | PASS |
| Theme files present in assembled profile (38) | PASS |
| Legacy-path coverage (assembled vs legacy `profile/`) | PASS (0 missing) |
| Path-diff EXTRA beyond `expected_extra` | **0** with HEAD + these changes |
| All config references resolve (include, banner, icons_dir, selections, 3 icons) | PASS (8/8) |
| `func_shutdown` / `func_reset` / `func_firmware` icons present | PASS |
| `refind.conf` copies identical (md5) | PASS (4/4) |
| Artwork fidelity vs zip (`background.png`, x ≥ 1200) | PASS (0 px differ) |
| Wordmark region: no upstream-branding pixels remain | PASS |
| `bash -n` build.sh, validate.sh | PASS |
| Full `./build/validate.sh` | 1 PRE-EXISTING failure — see note |

**Pre-existing failure note.** The full validator currently reports 19
EXTRA paths (`airootfs/etc/dconf/*`, `ash-panel@echoos`, `EchoOS-Lock`,
Calamares `hicolor` icons, …). These come from **uncommitted work-in-progress
in `ash-desktop` and `mad-install`** that predates this integration: a
pristine git-HEAD assembly reports 0 EXTRA, and HEAD + only this
integration's changes also reports 0 EXTRA. Completing `expected_extra` for
those components is their owners' change, not part of boot-theme work.

## 5. Behaviour preserved / changed

- **Preserved:** Echo OS live entry (same loader/initrd/options), UEFI
  fallback (`EFI/BOOT/BOOTx64.EFI` is rEFInd), `echoos.conf`, systemd-boot
  loader entries, Syslinux BIOS path (separate from rEFInd, untouched),
  keyboard navigation (arrows/Enter/F2/Insert), no hardcoded UUIDs or
  laptop-specific paths, Secure Boot posture unchanged (rEFInd ships
  unsigned as before; disable Secure Boot or enrol via MOK as previously).
- **Added:** automatic discovery of installed Windows and other EFI loaders
  (`scanfor manual,internal,external,optical` — previously `manual` only,
  per requirement §4); an accessibility entry matching the existing
  systemd-boot entry and the component README's documented contract.
- **Out of scope (echo-install):** the installed system's bootloader is
  written by Calamares (`mad-refindconf-write`); making installed systems
  adopt the theme is a follow-up there — the theme directory is portable
  as-is (`themes/wolfe/` + one `include` line).

## 6. VMware UEFI testing

Existing VM: `~/VMs/EchoOS-Fox` (`firmware = "efi"` already set).

1. Build: `cd EchoOS-Build/EchoOS-DEV && ./build.sh` (needs sudo; produces
   `out/echoos-fox-<date>-x86_64.iso`).
2. VM settings → CD/DVD → use the new ISO; firmware is already EFI.
3. Power on → the Wolfe-style menu must show: purple background with the
   animal artwork bottom-right and "Echo OS" wordmark; Echo entries with
   the white "e" icon; tool row = shutdown, reboot, firmware (white glyphs).
4. Select the Echo entry → live environment boots as before.
5. Keyboard: arrows move selection (black panel + green accent highlight),
   Enter boots, F2/Insert opens the options editor, Esc returns.
6. If a second disk with Windows/another EFI OS is attached to the VM, its
   loader must appear as an extra auto-detected entry — including after
   `echoos` entries.
7. Resolution matrix — VM display set to 1280×800, 1920×1080, 2560×1440:
   background must fill the screen (`banner_scale fillscreen`), icons and
   selection scale remain crisp, no black borders or cropping artifacts.
8. Fallback path check: firmware boot menu → "EFI Internal Shell" or boot
   from `EFI/BOOT/BOOTx64.EFI` directly; the same themed menu must appear
   (rEFInd reads its config from the FAT ESP it was launched from).

## 7. Physical laptop testing

1. Write the ISO: `sudo dd if=out/echoos-fox-<date>-x86_64.iso of=/dev/sdX
   bs=4M status=progress oflag=sync` (or Ventoy).
2. Firmware setup: UEFI boot enabled; **Secure Boot off** (unchanged from
   prior releases) unless a signed/MOK setup already exists.
3. Boot → one-time boot menu → "UEFI: <USB device>".
4. Verify: themed menu renders; internal NVMe/ATA ESP entries are
   auto-detected — **Windows Boot Manager must appear** without any manual
   entry; USB media appear under external; the Echo entries boot the live
   environment; the firmware tool reboots into BIOS/UEFI setup.
5. Legacy/CSM laptop: BIOS boot still goes through Syslinux (unchanged,
   separate from rEFInd); do not enable CSM for the rEFInd test.
6. Keyboard-only navigation per §6.5.

## 8. Rollback

```bash
cd EchoOS-Build/EchoOS-DEV
git checkout -- build.sh build/validate.sh components/echo-boot
rm -rf components/echo-boot/config/EFI/BOOT/themes
# or restore the full pre-change snapshot:
tar -xzf backups/2026-11-03-pre-wolfe-echo-boot/echo-boot-component.tar.gz -C components/
```

SHA256 manifests of before/after state are in the backup directory.
