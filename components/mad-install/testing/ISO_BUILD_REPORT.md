# MAD Installer — ISO Build Report

Date: 2026-10-31 · Build machine: Arch Linux host (see ENVIRONMENT_REPORT.md)

## Method

The repository's real build path was used end-to-end — no side-channel ISO
process:

1. `build/config/components.tsv` — `echo-install` row replaced by
   `40  mad-install  components/mad-install  echo-core,echo-boot,echo-desktop`
   (documented Phase 9 change; rollback is a config edit,
   see `../MIGRATION.md`).
2. `build/config/overlays.tsv` — the four echo-install overlay rows renamed
   to `mad-install` (same destinations).
3. `build/template/profiledef.sh` — permission entries re-pointed to the MAD
   file names (`mad-installer.desktop` 1000:1000:755, launcher/sbin 755).
4. `build/validate.sh` — installer checks updated to MAD names + parity
   whitelist updated for the MAD migration (old echoos branding paths
   `removed`, MAD payload `expected_extra`).
5. `./build/validate.sh` → **PASSED** (assembly OK for x86_64 and aarch64).
6. `./build.sh` → assemble + `mkarchiso`.

## Build results (all with the real build.sh)

| Build | Result | Notes |
| --- | --- | --- |
| v1 | PASS — `out/echoos-fox-2026.10.30-x86_64.iso` (2.48 GB) | first MAD ISO; contained stale echo-install files (BUG-003) |
| v2 (clean) | PASS — same filename, rebuilt 01:45 | stale files removed from work tree; MAD-only payload |
| v3 (contrast fix) | PASS — rebuilt 02:1x | stylesheet.qss v2 (BUG-001/002 fix) |

## Warnings discovered (important for future builds)

- **mkarchiso stamp caching:** with existing `work/base.*` stamps mkarchiso
  exits 0 immediately and produces **no new ISO, with no error**. Stamps
  must be cleared (they are root-owned; `sudo rm -f work/base.*`) when the
  component payload changes. Recorded as BUG-003.
- **Overlay semantics:** `cp -a` overlaying never deletes — payload changes
  that remove/rename files leave stale files in a reused `work/` tree.
  Files removed in v2: `etc/calamares/branding/echoos/*` (15 files),
  old launcher/wrapper/refind scripts, old desktop entries.
- The ISO filename stays `2026.10.30` because `work/build_date` pins
  SOURCE_DATE_EPOCH; the MAD build therefore replaced the previous 10.30
  image in `out/` (the audited 2026.10.29 release in `releases/` is intact
  and SHA-256-verified).

## ISO content verification

- Assembly manifest + `build/validate.sh` parity check confirm the exact
  expected payload (MAD branding at `airootfs/etc/calamares/branding/mad`,
  `mad-installer-launcher`, `mad-refindconf-write`,
  `mad-refind-sync.hook`, hicolor icon, desktop + autostart entries; no
  echoos-branding remnants).
- Live-VM spot checks: MAD branding loads from `/etc/calamares`
  (F1 evidence), desktop shortcut "MAD Installer" with Echo mark icon,
  no old shortcut after the v2 rebuild.
- rEFInd live-boot payload: unchanged echo-boot mechanism (booted in UEFI
  VMs repeatedly during testing).
