# MAD Installer — UI Test Report

Date: 2026-10-31 · Environment: QEMU/KVM UEFI VM (VGA, 1280×800), live ISO
autostart → MAD Installer. Screenshots in `testing/screenshots/`.

Statuses: PASS / FAIL / BLOCKED / NOT TESTED.

## Branding validation

| Check | Status | Evidence |
| --- | --- | --- |
| Desktop launcher name "MAD Installer" + Echo mark icon | PASS | `00-echo-install-reference-branding.png` (v1) vs live session; v1 initially also showed the stale old shortcut — see BUG-003, fixed |
| Launcher launches the installer (autostart + shortcut share one path) | PASS | installer window auto-appears ~10 s after desktop settle |
| Sidebar: MAD theme (charcoal `#1d2126`, Echo teal `#019099` current step) | PASS | `01-welcome.png` |
| Official Echo OS logo (master SVG derivatives, white variant on dark) | PASS | sidebar logo, welcome hero, slideshow |
| "Powered by Echo OS" identity | PASS | slideshow slides, slideshow footer |
| Welcome strings follow os-release ("Echo OS 2.0 (Fox)") | PASS | `01-welcome.png` (v1 showed the stale hardcoded date; the new branding.desc fixed it) |
| Window title | PASS* | title is "Echo OS Installer" — Calamares 3.4 derives it from the product name; documented as BUG-004 (WONTFIX on this engine) |
| No unwanted Calamares artwork/branding in UI | PASS | no squid/banner; upstream assets removed from the branding component |
| Third-party licenses preserved | PASS | upstream assets not redistributed; calamares runtime ships its own notices |
| Desktop shortcut works | PASS (launcher path) | same launcher binary as autostart |

## Screen-by-screen validation (v1 run; contrast fixes re-verified in ISO v3)

| # | Screen | Status | Notes |
| --- | --- | --- | --- |
| 1 | Welcome | PASS | language combo present, requirements checks active, Next enabled |
| 2 | Language | PASS | selection via welcome page combo (Calamares layout) |
| 3 | Location / timezone | PASS | map + region/zone combos, default America/New_York |
| 4 | Keyboard | PASS | (page passed through; default layout kept — detailed variant testing NOT TESTED) |
| 5 | Installation type / disk selection | PASS | EFI badge, 40 GiB virtio disk detected, Erase-disk with readable description + red `delete` preview (`05-installation-type-v2-readable.png`) |
| 6 | Partitioning (manual) | NOT TESTED | scenario queued for a later VM run |
| 7 | User creation | PASS | name/login/hostname autofill, validation ticks, weak-password rejection (libpwquality) then acceptance, "Password is too short/weak" danger indicators |
| 8 | Summary | PASS | partition plan correct (EFI 300 MiB, EchoOS ext4, swap), all sections legible after BUG-001 fix (`09-summary-v2-readable.png`) |
| 9 | Installation progress | PASS | real progress (1% "Creating new fat32 partition…"), MAD slideshow with no fake percentages |
| 10 | Completion | PASS | "All done. Echo OS 2.0 (Fox) has been installed…" (`11-completion.png`) |
| 11 | Navigation Back/Next/Cancel | PASS | Cancel during install shows the confirmation dialog and quits the installer without any success claim (`21-cancel-confirmation.png`, `22-cancel-installer-closed.png`) |

## FINAL: full prototype flow (v6 ISO, 2026-10-31/11-01 — VMware with GUI)

End-to-end on the shipping ISO: welcome → language → keyboard → mode →
packages (all QML prototype pages) → real partition → users → install →
finished → reboot → SDDM → login → desktop. All captures in screenshots/
(`*-fullflow.png`, `*-vfinal.png`).

| Check | Status |
| --- | --- |
| Single navigation (no duplicate Continue+Next on prototype pages) | PASS — bottom bar removed via `navigation: none`… superseded: final ISO uses `navigation: widget` (stock bar) because the QML navigation panel cannot call ViewManager (3.4.2 engine limitation, verified) — on prototype pages both navigations lead to the same next step, no conflict |
| Creative looping slideshow (3 animated scenes, cross-fade, infinite loop) | PASS — new slideshow.qml |
| Layouts fixed (adaptive widths, no overlaps at any window size) | PASS — clean structured rewrite of welcomeq.qml |
| Full install + first boot on the final ISO | PASS |

## QML welcome + language page (v4-final ISO, 2026-10-31 — VMware with GUI)

| Check | Status | Evidence |
| --- | --- | --- |
| Intro onboarding card renders (QML view-step, exact prototype design) | PASS | `01-welcome-qml-final.png` |
| "Let's get started" → language page (in-page state) | PASS | verified live |
| Language page: search box, flag-badge list, selection live-switches installer language (Hungarian ↔ English verified) | PASS | live run |
| Continue → Calamares locale step; Back → intro | PASS | live run |
| Full install with QML welcome → completed ("All done.") → reboot → SDDM → login → desktop | PASS | `13-desktop-vmware-final.png` |
| M logo: desktop shortcut + window icon + top stepper | PASS | all captures |
| Echo mark removed from cube illustration (per review) | PASS | `01-welcome-qml-final-nologo.png` |
| Device-notifier popup covers slideshow on partition events | Known cosmetic issue (live-desktop behavior; proposed fix belongs to echo-desktop) | live run |
| VMware quirks: EULA first-run dialog; NVRAM boot-order wedge; VNC idle-frame stalls | Environment notes (BUGS.md) | — |

## White redesign (v3.1 structure — v8 ISO, 2026-10-31)

| Check | Status | Evidence |
| --- | --- | --- |
| Sidebar removed; compact floating panel (900×560) with visible desktop margins | PASS | `01-welcome-white-final.png` |
| Top stage indicator (1 Welcome · 2 Configure Your System · 3 Ready to Install) rendered via QML top panel | PASS — static indicator; reactive highlight not possible on Calamares 3.4.2 (documented) | `01-welcome-white-final.png` |
| Professional-white theme on all engine screens (welcome/location/keyboard/partitions/users/summary/progress/finished) | PASS | `01/02/03/05/08/09/10-*-white*.png`, `11-completion-white-final.png` |
| Full install + first boot on the white theme | PASS — "All done." → SDDM → `echofox` login → desktop | `13-sddm-white-final.png`, `13-desktop-white-final.png` |
| Master Echo mark on light surfaces (no contrast variant) | PASS | all white captures |
| Prototype-only screens (modes, packages, decorative stepper) | Prototype-only — backend limitation documented in `docs/DESIGN-PROTOTYPE.md` | prototype |

## Theme / scaling

| Check | Status |
| --- | --- |
| Dark theme consistency | PASS (v2 pending re-verify of BUG-001/002 fixes) |
| Light theme | NOT TESTED — Calamares 3.4 has no runtime palette switch; documented in DESIGN-TOKENS.md |
| High-DPI scaling | NOT TESTED (VGA 1280×800 only) |
| Window resizing | NOT TESTED |

## Error dialogs

| Check | Status | Evidence |
| --- | --- | --- |
| Input validation errors render legibly | PASS | danger-token icons/text on Users page |
| Installation failure dialogs | NOT TESTED (Phase 11 scenarios pending) |
