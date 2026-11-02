# MAD Installer — Boot Test Report

Date: 2026-10-31 · UEFI (OVMF) unless stated. Disposable qcow2 only.

## rEFInd validation (installed system)

Verified **from inside the installed Echo OS** (screenshot
`testing/screenshots/12-boot-verification.png`):

| Check | Result |
| --- | --- |
| ESP created and mounted | PASS — `vda1 vfat FAT32 268.2M` mounted at `/boot/efi` (`lsblk -f`) |
| rEFInd loader installed on ESP | PASS — NVRAM entry `Boot0008* rEFInd Boot Manager … \EFI\refind\refind_x64.efi` (`efibootmgr`) |
| Kernel discoverable | PASS — `vmlinuz-linux` + `initramfs-linux.img` + `refind_linux.conf` at the ESP root (`ls /boot`); boot entries never rely on the ext4 driver (rEFInd 0.14.2 limitation, documented in the component README) |
| Root parameters correct | PASS — system boots to a working root (mount + login prove `root=UUID=` resolution) |
| Firmware boot entry configured | PASS — `efibootmgr` entry present; `BootCurrent: 0009` (removable-media fallback path also published, per `mad-refindconf-write`) |
| Actual boot process | PASS — ISO detached, VM booted from disk straight to the Echo OS SDDM greeter (`13-desktop-first-login.png` shows the greeter with user `echof`) |

## First boot validation

| Check | Result | Evidence |
| --- | --- | --- |
| rEFInd / boot chain (ISO detached) | PASS — firmware → rEFInd → kernel/initramfs → root mount | boot-01.png (SDDM up ~25 s after power-on) |
| Display manager | PASS — SDDM with Echo OS theme, user `echof` listed, Plasma (Wayland) session | boot-01.png |
| Login works | PASS — `MadTest2026!` accepted | boot-02.png |
| Desktop starts | PASS — Plasma (Wayland) session, Echo OS desktop theme, Welcome Center | boot-02.png |
| Kernel | PASS — `uname -r` → `7.2.11-arch1-1` | `12-os-identity-check.png` |
| OS identity | PASS — `PRETTY_NAME="Echo OS 2.0 (Fox)"`, `ID=echoos`, `VERSION_ID=2.0`, `IMAGE_ID=echoos-fox` | `12-os-identity-check.png` |
| Hostname | PASS — `echo-standardpc` (as configured in the installer) | boot prompt + `cat /etc/hostname` |
| User | PASS — `uid=1000(echof) gid=1000(echof) groups=…,wheel` | `14-boot-final-checks.png` |
| Failed units | PASS — `systemctl --failed` → `0 loaded units listed` | `12-os-identity-check.png` |
| Journal errors | PASS — only `virt/tdx: TDX not supported by the host platform` (harmless QEMU notice); no real errors | `14-boot-final-checks.png` |
| Networking | PASS (basic) — networkd+resolved enabled by the installer; NAT networking active in the VM session (not stress-tested) |

## BIOS (legacy) boot — **PASS** (2026-10-31, v4 ISO)

Full SeaBIOS VM run (no OVMF), fresh 40 GiB disposable disk:

| Check | Result | Evidence |
| --- | --- | --- |
| Live ISO boots in BIOS mode | PASS — syslinux menu → kernel → live session | `17-bios-summary-msdos.png` context |
| Partition page detects BIOS firmware | PASS — "BIOS" badge (vs "EFI" on UEFI runs) | `17-bios-summary-msdos.png` |
| Erase-disk plan uses MSDOS table, no ESP | PASS — "Creating new MSDOS partition table on /dev/vda", root 33.77 GiB ext4 + swap 6.23 GiB, "Install boot loader on /dev/vda" | `17-bios-summary-msdos.png` |
| Install completes | PASS — "All done." | `18-bios-completion.png` |
| GRUB installed for BIOS | PASS — `/boot/grub` contains `i386-pc` (plus grub.cfg, fonts, locales, themes) | `20-bios-grub-layout.png` |
| Disk layout | PASS — `vda1 ext4 /`, `vda2 swap`; **no ESP** (MSDOS) | `20-bios-grub-layout.png` |
| Reboot from disk (ISO detached) | PASS — SeaBIOS → GRUB MBR → kernel → SDDM → login → Plasma desktop | `19-bios-desktop-login.png` |
| Identity | PASS — `echof@echo-standardpc` (same as UEFI install) | `20-bios-grub-layout.png` |

One environment note: the first BIOS run was killed when /tmp filled up
(qcow2 write error) — a host-resource failure, not an installer failure;
the rerun completed cleanly.
