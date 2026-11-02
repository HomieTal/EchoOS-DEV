# MAD Installer — Roadmap

## Current implementation (v1 — this milestone)

- Independent component `components/mad-install` (verified fork of
  `echo-install`; original untouched).
- MAD Installer identity ("MAD Installer — Powered by Echo OS"), Echo OS
  mark artwork, dark charcoal + Echo teal theme, custom slideshow.
- Calamares 3.4.2 engine retained; module sequence unchanged and verified.
- rEFInd (UEFI) / GRUB (BIOS x86_64) boot setup, kernel-update resync hook.
- Independent `packaging/PKGBUILD` (`mad-installer` package).
- Documentation set: README, ARCHITECTURE, DEPENDENCIES, TESTING, MIGRATION,
  DESIGN-TOKENS, PHASE5-FINDINGS.

## Upcoming milestones

### v1.1 — Integration hardening
- Wire `mad-install` into `components.tsv`/`overlays.tsv` and retire
  `echo-install` from the ISO build (keep the component for reference).
- Extend `build/validate.sh` with MAD checks (branding `mad`, launcher,
  desktop entry, icon).
- Regenerate branding assets in the build pipeline from the master SVG
  (reproducibility), not by hand.

### v1.2 — UX refinement
- Light theme tokens once a Calamares version supports palette switching.
- Summary page: highlight destructive operations per-disk with the `danger`
  token (requires upstream module cooperation or a custom summary module).
- Localization strategy for MAD-specific strings (branding strings are
  untranslatable in Calamares; evaluate a translations module).

### v2 — Independent engine (the actual goal)

Design constraint: `ARCHITECTURE.md` §5 contracts are the seam.

1. **Installation API** — a typed interface (disk query/plan/commit, payload
   deploy, configure, progress/error events) implemented first as a shim
   over the Calamares backend so the API is exercised while Calamares is
   still the engine.
2. **MAD UI v2** — Qt/QML frontend speaking the Installation API directly
   (unlocks the full layout freedom that Calamares 3.4 cannot offer: real
   light/dark switching, QML step panels, responsive layouts).
3. **Backend evaluation, independently per capability** (never big-bang):
   disk: kpmcore vs libblockdev vs sfdisk plans;
   payload: unpackfs vs image-based deployment;
   boot: current rEFInd/GRUB glue vs MAD boot-manager component.
4. Only when the Calamares runtime, libraries and modules are fully replaced
   may the engine be called independent — until then, docs will keep saying
   "Calamares-based".

Non-goals for v2: network installation, other distributions' package
management, aarch64 installer (until a real requirement exists).
