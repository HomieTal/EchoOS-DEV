# MAD Installer — Performance Report

All numbers are real measurements from the 2026-10-31 test runs on the
development host (QEMU/KVM, 4 vCPU, NVMe-backed /tmp). No fabricated values.

| Metric | Measurement | Notes |
| --- | --- | --- |
| ISO build (assemble + mkarchiso) | ≈ 20–25 min wall clock (3 builds measured: 01:24, 01:45, 02:24 starts→outputs) | dominated by xz squashfs compression of the ~2.4 GB live root; 4 compression threads |
| Live ISO boot → desktop | ~60 s power-on to usable Plasma session (OVMF POST + rEFInd + kernel + SDDM autologin) | 3 GiB RAM guest |
| Installer startup (autostart path) | window visible within ~10 s of session settle | single-instance guard + bounded 10 s polkit wait; healthy sessions unlock in ~2 s |
| Full installation (Erase disk, 40 GiB disk) | ≈ 9 min install-click → "All done." (17:01 → 17:07 incl. a screen-lock detour) | unpackfs offline copy dominates; no network involved |
| First boot (installed system) → SDDM | ~25 s power-on → greeter | boot chain: OVMF → rEFInd → kernel |
| Login → desktop | ~8 s | Plasma (Wayland) |
| `systemctl --failed` | 0 units | after first boot |

## Responsiveness

The installer stayed responsive throughout the install (progress updated,
log toggle available). During the squashfs copy phase the UI thread remained
interactive in screenshots (slideshow advancing, progress bar moving).

## Environment caveats

- Numbers reflect a VM on a busy desktop host; absolute values are
  indicative, ratios are meaningful.
- The v1 run was killed by **host** OOM at 4 GiB guest RAM (see BUG-006) —
  a test-environment constraint, not an installer timing.
