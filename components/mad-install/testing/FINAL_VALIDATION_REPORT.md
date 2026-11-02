# MAD Installer — Final Validation Report

Date: 2026-10-31 · Verdict: **MAD Installer validated for first Echo OS
integration** (end-to-end install + boot proven; see scope notes).

## Build status

| Item | Status |
| --- | --- |
| Independent package build (`mad-installer-1.0.0-1-x86_64.pkg.tar.zst`) | PASS (`BUILD_REPORT.md`) |
| Component validation (`validate-mad.sh`) + repo validation (`build/validate.sh`, x86_64 + aarch64) | PASS |
| ISO build via the real `build.sh` (3 builds) | PASS (`ISO_BUILD_REPORT.md`) |
| Dependency status | complete for x86_64; aarch64 has no installer by design |

## UI status

| Item | Status |
| --- | --- |
| Branding: MAD Installer identity, Echo OS mark, "Powered by Echo OS" | PASS (`UI_TEST_REPORT.md`) |
| All implemented screens render; navigation works | PASS (welcome/location/keyboard/partitions/users/summary/progress/completion) |
| Theme: dark charcoal + Echo teal, text contrast fixed and re-verified on screen | PASS (BUG-001/002 fixed in ISO v3) |
| Desktop launcher + autostart (single launch path, pkexec only) | PASS |
| No unintended Calamares branding | PASS (no upstream artwork shipped; window title still "Echo OS Installer" — BUG-004, engine constraint) |
| Light theme / High-DPI / window resizing | NOT TESTED (documented; Calamares 3.4 has no runtime palette switch) |

## Installation status (UEFI, disposable 40 GiB qcow2)

| Item | Status |
| --- | --- |
| Disk detection + virtual disk selection | PASS (vda 40 GiB, EFI badge) |
| Partitioning (erase-disk workflow, destructive preview) | PASS |
| Filesystem creation | PASS (ESP 300 MiB FAT32, root 33.49 GiB ext4, swap) |
| Package installation (offline unpackfs) | PASS |
| User creation | PASS (uid 1000, wheel/network/video/storage groups) |
| System configuration | PASS (locale, keyboard, timezone, hostname, SDDM, networkd+resolved) |
| Bootloader configuration | PASS (rEFInd — UEFI; GRUB i386-pc — BIOS; see BOOT_TEST_REPORT) |
| Installation completion | PASS ("All done.") |
| Cancellation | PASS — confirmation dialog, clean quit, no false success (`INSTALLATION_TEST_REPORT.md` Test D) |
| Insufficient-disk failure | PASS with fix — graceful failure documented; storage check now blocking (BUG-007, verified) |
| Manual partitioning / existing-ESP scenarios | NOT TESTED (queued — no results claimed) |

## Boot status

| Item | Status |
| --- | --- |
| UEFI boot of installed system (ISO detached) | PASS |
| rEFInd (NVRAM entry, ESP layout, kernel/initramfs discoverable) | PASS |
| BIOS (SeaBIOS) install + GRUB MBR boot | **PASS** — MSDOS layout, `i386-pc` GRUB, reboot → desktop (`BOOT_TEST_REPORT.md`) |
| Display manager + first login + desktop | PASS (both UEFI and BIOS installs) |
| Kernel / initramfs / root mount | PASS (`7.2.11-arch1-1`, ext4 root) |
| `systemctl --failed` = 0, journal clean | PASS |

## Known issues

See `BUGS.md`: BUG-001/002 contrast (FIXED, verified on screen), BUG-003
stale-workdir build hazard (fixed for this build; build.sh hardening
recommended), BUG-004 window title (engine constraint), BUG-005 slideshow
title overlap (cosmetic, open), BUG-006 host OOM during tests (environment).

## Remaining Calamares dependencies

MAD Installer is **not** engine-independent, and nothing in the docs claims
it is. Still provided by the Calamales 3.4.2 runtime:

- Calamares core (`calamares` binary, libcalamares, libcalamaresui)
- KF6 runtime: kconfig, kcrash, kpackage; kpmcore (partitioning)
- Modules: welcome, locale, keyboard, partition, users, summary, mount,
  unpackfs, removeuser, machineid, localecfg, fstab, initcpiocfg, initcpio,
  displaymanager, hwclock, services-systemd, packages, shellprocess,
  umount, finished
- Qt6 runtime shared by Calamares

Independence path: `../ROADMAP.md` (Installation API shim → UI v2 →
per-capability backend replacement).

## Acceptance criteria (`MASTER TASK` §17)

Independent package builds ✅ · launches ✅ · official Echo OS logo ✅ ·
MAD branding consistent ✅ · no unintended Calamares UI branding ✅ ·
navigation works ✅ · all supported screens work ✅ · ISO builds ✅ ·
live ISO boots in UEFI ✅ · installer starts ✅ · virtual disk detected ✅ ·
partitioning works ✅ · EFI handling works ✅ · filesystem creation works ✅ ·
package installation works ✅ (offline unpackfs) · user creation works ✅ ·
rEFInd installation works ✅ · installation completes ✅ · ISO detached ✅ ·
installed Echo OS boots independently ✅ · user login works ✅ ·
desktop works ✅ · logs and reports generated ✅ (this directory)

## Scope honestly stated

- Two full installs verified end-to-end (UEFI/rEFInd and BIOS/GRUB), plus
  cancellation and insufficient-disk failure paths. Manual partitioning and
  existing-ESP preservation remain queued (TESTING.md), not claimed.
- Hardware tests not performed.
- Engine remains Calamares 3.4.2 (by design, phase 1 of the roadmap).
