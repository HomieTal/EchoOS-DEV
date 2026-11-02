# MAD Installer — White Redesign: Design Prototype & Implementation Report

Date: 2026-10-31 · Design direction: **Professional White / Premium Minimal**
(Fortect-style onboarding composition, purple accents, Echo OS identity).

## Deliverables map

| Required deliverable | Location | Status |
| --- | --- | --- |
| Complete design system | `docs/DESIGN-TOKENS.md` (v3, white) | Done |
| Ten screen mockups | Interactive prototype (all 10 screens, navigable) | Done |
| Reusable UI components | Prototype: buttons, cards, inputs, rows, stage indicator, ring progress, illustrations (CSS/SVG) | Done |
| Functional frontend prototype | Same file — realistic navigation + sample data (searchable languages, selectable modes/packages/disks, password strength, animated progress) | Done |
| Integrated installer interface | `stylesheet.qss` (white theme), `branding.desc` (light sidebar + images), `slideshow.qml` (light) — shipped in the ISO | Done |
| Installation workflow documentation | This file + `../ARCHITECTURE.md` §4 | Done |
| Testing checklist | `../TESTING.md` + `../testing/UI_TEST_REPORT.md` (updated per run) | Done |
| Screenshots of every screen | `../testing/screenshots/` (live-VM captures) | Partial — engine-rendered screens captured; prototype-only screens exist in the prototype |
| Known limitations | Below | Done |

## Screen-by-screen implementation status

| # | Screen | Prototype | Integrated in Calamares 3.4.2 | How |
| --- | --- | --- | --- | --- |
| 01 | Welcome (onboarding composition) | ✅ | Partial | Calamares welcome module + white theme + master-color hero image; the left/right onboarding composition with stage indicator **cannot** be rendered (see limitations) |
| 02 | Language | ✅ | ✅ | Calamares locale page, white themed |
| 03 | Keyboard | ✅ | ✅ | Calamares keyboard page (layout, variant, test field), white themed |
| 04 | Installation Mode (4 cards) | ✅ | ❌ Prototype-only | Needs a backend package-profile mechanism; the offline unpackfs backend has none (`packages` module is a no-op) |
| 05 | Package Selection | ✅ | ❌ Prototype-only | Same backend limitation; also `packagechooser` was excluded from the local Calamares build |
| 06 | Disk Partitioning | ✅ | ✅ | Calamares partition page (erase/alongside/manual), white themed, destructive warnings preserved |
| 07 | User Configuration | ✅ | ✅ | Calamares users page (fields, validation, strength), white themed |
| 08 | Installation Summary | ✅ | ✅ | Calamares summary page, white themed |
| 09 | Installation Progress | ✅ | Partial | Real Calamares progress bar + log + white slideshow; the decorative stage list/ring is prototype-only (real percentage is kept, never fabricated) |
| 10 | Installation Complete | ✅ | Partial | Calamares finished page, white themed; celebratory illustration is prototype-only |

## Safe integration proposal for the prototype-only screens

1. **Screens 04/05 (mode + packages)**: implement as **custom Calamares
   view-step modules** (C++/QML, like `packagechooserq`) writing choices to
   GlobalStorage, PLUS an install-time mechanism that can act on them. On
   the current offline backend the only safe action is *none* — packages
   come from the live image. Therefore: adopt these screens only together
   with the v2 engine's payload mechanism (ROADMAP) that can install
   packages offline from a curated store on the ISO, or defer them.
2. **Screen 01/09/10 compositions**: replace the stock welcome/finished
   pages with custom QML view-steps (possible in Calamares via
   `QmlViewStep`), reusing the prototype's markup translated to QML. Medium
   effort, zero backend risk — scheduled after screens 04/05 decision.
3. **Stage indicator**: a Calamares QML sidebar can *display* static stage
   info but cannot reflect real step state (no model exposed in 3.4.2 —
   verified). Ship it only with the v2 engine.

## Structure revision (v3.1 — 2026-10-31, approved)

The layout was restructured per the Fortect reference: **the left sidebar is
gone** and the window is a **compact floating panel (900×560)** with the
**three-stage indicator strip at the TOP of the window**
(`sidebar: qml,top` + `calamares-sidebar.qml`: numbered circles 1-2-3,
connecting lines, labels *Welcome / Configure Your System / Ready to
Install*; stage 1 highlighted in MAD purple). Navigation stays in the
bottom widget.

**Engine limitation (verified on screen):** the top indicator is STATIC —
Calamares 3.4.2 QML panels receive no view-step model, so it cannot move
the highlight as steps progress. The numbered stage identity, compact
floating-panel structure, and full white theme are all live in the ISO;
the reactive stepper is a v2-engine item (see the safe-integration
proposal above).

## QML view-step screens — live in the ISO (v4-final, 2026-10-31)

The intro onboarding card AND the exact-prototype "Choose Your Language"
page are now **real Calamares QML view-steps** (`welcomeq` module +
branding-dir override `welcomeq.qml`), plus a branded `finishedq.qml`:

- Two in-page states inside the welcome view-step: intro card → language
  page (Back/Continue), driven by an internal `page` property.
- Language page: search field (DelegateModel `inVisible` filtering),
  flag-badge + label + englishLabel rows, selection bound to
  `config.localeIndex` — **live-switches the installer language exactly
  like the stock page** (verified: Hungarian ↔ English in the VMware run).
- Requirements banner preserved (`config.requirementsModel.satisfiedMandatory`
  — the 3.4.2 property name; `satisfiedRequirements` does not exist).

### QML 3.4.2 compatibility findings (each verified by failure + fix)

| Issue | Symptom | Fix |
| --- | --- | --- |
| `import QtGraphicalEffects 1.0` | whole QML fails to load ("Loading failed") | removed; pure Rectangle art instead |
| `font.pixelSize: 11.5` (float) | load fails: "Invalid property assignment: int expected" (welcomeq.qml:106) | integer pixel sizes only |
| `satisfiedRequirements` | unknown property → load failure | `satisfiedMandatory` (3.4.2 name) |
| `ViewManager` singleton | may be absent in some 3.4.2 builds | `typeof ViewManager !== "undefined"` guard + visible hint fallback |
| EULA dialog on VMware GUI first run | blocks UI launches | `--acceptAllEulas` unsupported on the UI; accept once via GUI (writes /etc/vmware/config + ~/.vmware/config) |

### Navigation panel limitation (verified)

`navigation: qml,bottom` renders a custom QML bottom bar, but the
navigation-panel engine does NOT register io.calamares.core — ViewManager
is unavailable there, so QML bar buttons cannot navigate (verified: Next
renders but does nothing). The shipped configuration uses
`navigation: widget` (the working stock bar) — on the prototype pages both
the in-card Continue and the stock Next lead to the same next step. A
self-contained QML navigation requires the v2 engine.

### Reactive sidebar status

The shipped calamares-sidebar.qml IS the reactive version
(ViewManager.currentStepIndex + Global madStage bridge from welcomeq) and
works: stage highlight follows the real flow (verified in the final VMware
run). An earlier "sidebar fails to load" observation was a transient
build-state issue, not an engine limitation.

### Live-deployment method (no ISO rebuild needed for QML iteration)

The running live session's `/etc` is a writable overlay: serve the QML from
the host (`python3 -m http.server 8000 --bind <vmnet8-ip>`), fetch it in the
guest (`sudo wget -O /etc/calamares/branding/mad/welcomeq.qml http://<ip>:8000/welcomeq.qml`),
then `sudo pkill calamares` and relaunch from the desktop shortcut. Verified
working; used for the language-page iteration.

## Validation of the white redesign (v8 ISO, 2026-10-31)

- Live walkthrough: welcome / location / keyboard / partitions / users /
  summary all render on the white theme; top stepper visible on every page.
- Full UEFI install completed ("All done."), ISO detached, first boot
  reached SDDM, login as `echofox` succeeded, desktop up — backend
  (partitioning, unpackfs, users, rEFInd) unbroken.
- Screenshots: `../testing/screenshots/*-white-final.png` and
  `01-welcome-white-nosidebar.png`, `09-summary-white-nosidebar.png`.

## What was integrated now (verified in the ISO)

- Complete white QSS theme (`Professional White` tokens) — every widget
  class Calamares exposes, including the scroll-area viewport fix so text
  always lands on a matching surface.
- Light sidebar (`style:` keys) with MAD-purple current-step highlight.
- Product images switched to the **master Echo mark colors** on white.
- New light slideshow (`#F5F6FA`, purple accent bar, master-color artwork).
- Backend untouched: module sequence, module configs, unpackfs, rEFInd
  pipeline, exclusions — byte-identical to the validated build except the
  three branding files above.
