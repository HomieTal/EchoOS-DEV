# Copy Verification Report — Phase 2 (MAD Installer)

Date: 2026-10-31
Source: `components/echo-install` (untouched reference)
Copy: `components/mad-install`

## Method

1. `cp -a components/echo-install components/mad-install` — archive mode,
   preserving mode bits, executable bits, and timestamps.
2. `diff -r` across the full tree.
3. Per-file SHA-256 comparison (`sha256sum` of every file, sorted, diffed).
4. Per-path `stat` comparison (mode string, octal mode, file type, sorted, diffed).

## Results

| Check | Result |
| --- | --- |
| File count | 57 / 57 (identical) |
| `diff -r` | clean — no content differences |
| SHA-256 | all 57 files identical |
| Permissions (mode/type per path) | identical |
| Executable bits preserved | `echoos-install.desktop` (755), `echoos-install-launcher` (755), `echoos-calamares` (755), `echoos-refindconf-write` (755) |
| Directory structure | preserved (initial Phase-2 state) |

## Integrity of the original

`git status` confirms `components/echo-install` carries **no modifications** —
the only working-tree entries before Phase 2 were two pre-existing untracked
files (`components/echo-boot.zip`, `logo_black.jpeg`).

## Notes for Phase 3+

The copy is intentionally byte-identical at this point. Customization begins
only after this verification. Pending changes (per approved plan):

- Remove upstream Calamares artwork (`banner.png`, `squid.png`, `languages.png`
  and their `.license` files) from MAD branding; MAD ships only Echo OS–derived
  artwork from the master `echo-mark.svg`. License attribution obligations are
  unaffected: the Calamares runtime ships its own notices, and no upstream
  branding files are redistributed inside the MAD branding component.
- Rename branding component to `mad`, rebrand strings, desktop entries, launcher
  names.
