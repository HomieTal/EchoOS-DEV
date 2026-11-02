# MAD Installer — Build Report

Date: 2026-10-31

## 1. Independent package build (`packaging/PKGBUILD` → `mad-installer`)

Executed outside the ISO pipeline, from a pristine copy of the component:

```bash
cp -a components/mad-install /tmp/mad-pkgtest/mad-install
tar czf mad-install.tar.gz mad-install          # source artifact
# PKGBUILD with source=("mad-install.tar.gz")    (test harness only)
makepkg -f --skipinteg
```

Result: **PASS** — `mad-installer-1.0.0-1-x86_64.pkg.tar.zst` (66,846 bytes).

- Package inventory verified (`pacman -Qlp`, 65 entries): `/etc/calamares`
  (settings.conf, 18 module confs, `branding/mad/` with master SVG + all
  PNG variants + stylesheet + slideshow), `/usr/local/bin/mad-installer-launcher`,
  `/usr/local/bin/mad-installer-x11`, `/usr/local/sbin/mad-refindconf-write`,
  `/usr/share/libalpm/hooks/mad-refind-sync.hook`,
  `/usr/share/applications/mad-installer.desktop`,
  `/usr/share/icons/hicolor/64x64/apps/mad-installer.png`, docs.
- Architecture: x86_64 only (aarch64 explicitly unsupported —
  `packages.aarch64` is empty; nothing advertises ARM support).
- Fix applied during testing: `$srcdir` is now resolved inside
  `build()`/`package()` (it is not set while the PKGBUILD is sourced); this
  was a real PKGBUILD bug caught by the independent build.

## 2. Component validation

`components/mad-install/scripts/validate-mad.sh` → **PASSED**
(branding integrity, asset references, identity sweep, desktop entries,
exclude-list consistency, launch path, qmllint).

`build/validate.sh` (repo-wide, after Phase 9 registration) → **PASSED**
for both x86_64 and aarch64 assembly.

## 3. Runtime dependency verification

- `packages/packages.x86_64`: `calamares`, `kconfig`, `kcrash`,
  `kpackage` (KF6 libs the local calamares build links against but does not
  declare). Present in the built ISO; Calamares starts in the live session
  (proven on screen).
- Local calamares 3.4.2 artifact present (`packages/calamares-3.4.2-2-x86_64.pkg.tar.zst`).

## 4. Branding / no-legacy check

- No upstream Calamares artwork in the MAD branding component (validator).
- No stale Echo Install script identities (validator).
- Live-VM confirmation: only "MAD Installer" appears on the desktop; the
  installer window, sidebar, slideshow and dialogs carry MAD identity
  (screenshots `testing/screenshots/`).
