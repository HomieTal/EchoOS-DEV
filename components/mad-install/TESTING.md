# MAD Installer — Testing

## Automated checks (this repository)

Run from the repo root; they only read the component tree:

1. **Branding integrity** — `branding: mad` in `settings.conf`;
   `branding/mad/branding.desc` exists with `componentName: mad`; no
   upstream Calamares artwork in `branding/mad/`; referenced images all
   exist.
2. **Identity sweep** — no stale `echoos-install-launcher` /
   `echoos-calamares` / `echoos-refind` references inside
   `components/mad-install` (Echo OS *OS-level* identity strings are
   intentionally retained and whitelisted).
3. **Desktop integration** — desktop entries reference
   `mad-installer-launcher`, `Icon=mad-installer`, the hicolor icon exists.
4. **Exclude list consistency** — the launcher/autostart files that
   `exclude-list.txt` strips are the files this component ships.
5. **QSS/QML syntax** — `qmllint` on `slideshow.qml` (Calamares modules
   import-warnings expected outside the Calamares runtime).

Phase 8 runs these as a script (`scripts/validate-mad.sh` when added) and
records results in the phase report.

## VM tests

Environment: QEMU/KVM (q35, OVMF UEFI or SeaBIOS), 4 GB RAM, disposable
qcow2 disks under `/tmp` — **never** the developer's real disks.

| # | Scenario | Covers |
| --- | --- | --- |
| 1 | Boot audited 2026.10.29 ISO, verify branding loads from `/etc/calamares` | F1 path mechanism (done, Phase 5) |
| 2 | Boot MAD ISO (UEFI): MAD branding, welcome screen, navigation | MAD frontend live |
| 3 | Full "Erase disk" install to the disposable disk (UEFI) | partition → unpackfs → users → boot setup |
| 4 | Reboot after install: rEFInd menu, Echo OS desktop reachable | boot chain end-to-end |
| 5 | Existing-ESP / alongside scenario (second virtual disk with a foreign ESP) | EFI preservation |
| 6 | BIOS (SeaBIOS) install | GRUB MBR path (F3) |
| 7 | Failure path: install with too-small disk → error surfaces, no false success | error reporting |

## Known limitations

- No automated UI-interaction suite yet: VM scenarios are driven via QMP
  screenshots/key events and verified visually.
- aarch64: no installer, therefore no VM matrix for it.
- Kernel-update resync hook (`mad-refind-sync.hook`) is exercised only
  indirectly (static review) until a test installs kernel updates in the VM.

## Hardware tests

Not performed in this milestone. Before any release: real UEFI machine,
real dual-OS machine (ESP preservation), and a BIOS machine are required.
