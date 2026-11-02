# MAD Installer — Installation Test Report

Date: 2026-10-31 · VM: QEMU/KVM q35, OVMF UEFI, 3 GiB RAM, 4 vCPU,
disposable 40 GiB qcow2 (`/tmp/mad-vm/testdisk.qcow2`). ISO:
`out/echoos-fox-2026.10.30-x86_64.iso` (MAD build v3, contrast-fixed).

Statuses: PASS / FAIL / BLOCKED / NOT TESTED.

## Test A — Fresh UEFI installation (Erase disk): **PASS**

Driven end-to-end through the real UI (QMP input + screenshots at every
step; screenshots in `testing/screenshots/`):

| Step | Result | Evidence |
| --- | --- | --- |
| Live boot → MAD Installer autostart | PASS | desktop shortcut "MAD Installer", installer window up |
| Welcome → language kept (American English) | PASS | `01-welcome.png` |
| Location: America/New_York | PASS | `02-location-timezone.png` |
| Keyboard: us default | PASS | passed through |
| Partitions: "Erase disk" on vda (40 GiB), destructive preview readable | PASS | `05-installation-type-v2-readable.png` |
| Users: name "echo fox", login `echof`, hostname `echo-standardpc`, password accepted after weak-password rejection | PASS | `08-user-creation-valid.png` |
| Summary: Before/After bars, explicit partition ops, destructive changes identified | PASS (after BUG-001 fix) | `09-summary-v2-readable.png` |
| Install → progress with real operations ("Creating new fat32 partition on /dev/vda…") and MAD slideshow | PASS | `10-installation-progress-v2.png` |
| Completion: "All done. Echo OS 2.0 (Fox) has been installed on your computer." | PASS | `11-completion.png` |

Partition result (verified in the installed system, `12-boot-verification.png`):
`vda1 vfat FAT32 268.2M /boot/efi` · `vda2 ext4 25.7G /` · `vda3 swap` —
GPT with ESP, root and swap, matching the summary.

## Test B — Manual partitioning: NOT TESTED
Queued; requires a separate VM run. No result is claimed.

## Test C — Existing EFI partition handling: NOT TESTED
Queued; requires a second virtual disk with a foreign ESP.

## Test D — Installation cancellation: **PASS**

Driven on a fresh UEFI VM (v4 ISO): install started, at 8 % ("Filling up
filesystems") Cancel was clicked.

| Check | Result | Evidence |
| --- | --- | --- |
| Confirmation dialog before quitting | PASS — "Cancel Installation? … The installer will quit and all changes will be lost." with Yes/No (No default) | `21-cancel-confirmation.png` |
| Installer quits on Yes | PASS — window closed, **zero calamares processes** remain | `22-cancel-installer-closed.png` |
| No false success | PASS — no completion screen; the installer simply exits | same |
| Partial-install state on disk | DOCUMENTED limitation: the disk keeps the partition layout and partial copy (Calamares does not roll back committed changes). Recovery = re-run the installer (erase-disk) — no user-facing recovery tool. | — |

## Test E — Insufficient disk (failure path): **PASS with fix (BUG-007)**

5 GiB disk, v3 ISO: the welcome page warned "There is not enough drive space.
At least 8 GiB is required." but Next stayed enabled; the install proceeded,
partitioned the disk, then failed at unpackfs with "Installation Failed —
rsync failed with error code 11" — reported clearly, **no false success**
(`15-failure-insufficient-disk.png`).

Fix: `welcome.conf` now lists `storage` under `required:`. Verified on the
v4 ISO: the welcome page states "Installation cannot continue", shows an
error icon, and **Next is disabled** on the 5 GiB disk; on the 40 GiB disk
the check passes normally (`16-storage-check-blocking.png`).

## Failed first attempt (environment, not installer)

The v1 run was killed at ~2 min into the install by a **host OOM**
(kernel: `Out of memory: Killed process … qemu-system-x86`) — 4 GiB guest
RAM against a busy 15 GiB host. Retry with 3 GiB guest RAM completed. See
BUG-006. The installer never reported a false success; the VM simply died.

## Installer logs

- Launcher: `/tmp/mad-installer-launcher.log` (live session).
- Bootloader finalization: `/var/log/echoos-bootloader.log` (target).
- Calamares session log available behind "Toggle log" in the progress view.
