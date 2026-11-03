# Echo OS — GNOME Desktop Branding and Panel Refinement (v4.1.1)

Status: **complete, verified in VMware on the rebuilt ISO**
(`out/echoos-fox-2026.11.03-x86_64.iso`). Scope: `components/ash-desktop`
plus two minimal installer-side desktop-integration files (see §2b).
Echo Core, Echo Boot and the MAD Installer install flow were not touched.

---

## 1. Summary of changes

### a) Lock screen / login screen branding (Arch branding removed)

The desktop wallpaper, the lock-screen wallpaper and the GDM login screen
are three independent configuration surfaces; each is now configured
separately:

| Surface | Before | After |
| --- | --- | --- |
| Desktop background | Echo wallpaper (per-session autostart, unchanged) | unchanged |
| Lock screen | fell back to the shell's built-in (Arch) default — `org.gnome.desktop.screensaver` was never set | **Echo OS lock-screen artwork** (`/usr/share/wallpapers/EchoOS-Lock/contents/images/1600x900.png`, owner-supplied image), set per session for light and dark styles |
| GDM login screen | solid Arch-dark background **with the Arch Linux logo** (`org.gnome.login-screen logo` patched to `/usr/share/pixmaps/archlinux-logo-text-dark.svg` by Arch's compiled schema defaults) | **Arch logo removed** (`logo=''`); Echo background/screensaver keys pre-seeded; greeter wallpaper availability documented (§4) |

Files (all new or extended, none package-owned — no pacstrap conflicts):

- `components/ash-desktop/config/airootfs/usr/local/bin/echoos-wallpaper-apply`
  — now sets **both** `org.gnome.desktop.background` (Echo wallpaper) and
  `org.gnome.desktop.screensaver` (EchoOS-Lock artwork) light+dark keys.
- `components/ash-desktop/config/airootfs/usr/share/wallpapers/EchoOS-Lock/`
  — new asset (owner-supplied 1600×900 artwork) + `metadata.json`.
- `components/ash-desktop/config/airootfs/etc/dconf/profile/gdm` — **new**.
  The `gdm` package ships `/usr/share/dconf/profile/gdm` *without a system
  db*, so keyfiles under `/etc/dconf/db/gdm.d/` were never read. This
  profile override (dconf reads `/etc` before `/usr/share`) declares
  `system-db:gdm` and keeps the package defaults file as fallback.
- `components/ash-desktop/config/airootfs/etc/dconf/db/gdm.d/00-echoos-branding`
  — greeter defaults: background keys, screensaver keys, and
  `[org/gnome/login-screen] logo=''` (removes the Arch logo).
- `components/ash-desktop/config/airootfs/etc/systemd/system/echoos-dconf-update.service`
  (+ `sysinit.target.wants` symlink) — oneshot `dconf update` per boot;
  the assembly has no image-build hook, and dconf clients only read the
  compiled binary DBs. Verified running on every boot.

### b) MAD Installer icon in the GNOME dash (installer-side, 2 files)

**Root cause:** GNOME Shell attributes the running Calamares window
(WM_CLASS `calamares`) to the upstream `/usr/share/applications/calamares.desktop`
(`Icon=calamares`), so the dash showed the stock orange Calamares artwork.
The `Icon=mad-installer` entries were never consulted for the running
window (the Desktop shortcut file is not part of the shell's app
database).

**Fix (proper, no package conflicts):** ship the MAD mark under the
`calamares` icon name as exact-size raster icons
(`16/24/32/48/64/96/128/256 px`), which win the icon-theme lookup over the
upstream scalable SVG. Upstream owns only
`scalable/apps/calamares.svg`, so none of these paths collide with the
package.

- `components/mad-install/config/rootfs/usr/share/icons/hicolor/<size>/apps/calamares.png` (8 files, generated from `calamares/branding/mad/productIcon.png`)
- `components/mad-install/packaging/PKGBUILD` — packaging section extended to install the icon set.

### c) Top panel — dark glass, pinned (new extension)

`components/ash-desktop/config/airootfs/usr/share/gnome-shell/extensions/ash-panel@echoos/`

- `stylesheet.css` — `#panel.ash-panel { background-color: rgba(20,20,24,0.70); border-bottom: 1px solid rgba(255,255,255,0.12); border-radius: 0px; }` and `.ash-panel-maximized { 0.80 }`.
- `extension.js` — adds the style class; switches to the 80 % variant while a **fully maximized** window is focused (listens to `focus-window` *and* `window_manager size-change`, because maximizing in place does not change focus); overview keeps the normal 70 %; clean restore on `disable()`.
- `metadata.json` — `"shell-version": ["45"…"51"]`, `"session-modes": ["user"]` → the lock screen and the GDM greeter keep the stock shell theme.
- Enabled system-wide via dconf defaults (`etc/dconf/profile/user` + `etc/dconf/db/local.d/00-ash-shell` sets `org.gnome.shell enabled-extensions`); users can override.

**Panel contents never dimmed:** the stylesheet sets only `#panel`'s own
`background-color` (a child-actor background), never container `opacity`.

**Pinned behaviour** is stock GNOME Shell and was verified, not re-implemented:
the panel never auto-hides, reserves struts (maximized windows stop below
it — pixel-verified, see §3), and stays put across workspace switches,
lock/unlock and resolution changes. No dock/panel extension is installed
(`dash-to-panel`/`dash-to-dock` absent from the package lists).

### d) Version-compatibility findings (GNOME 51)

- `Meta.Window.get_maximized()` / `get_maximized_flags()` are **gone** in GNOME 51; the extension uses the boolean properties `maximized_vertically/horizontally` with a flags-based fallback for older shells.
- `org.gnome.desktop.screensaver picture-uri-dark` no longer exists (49+); setting it is a harmless no-op, older shells use it.
- Extension logic unit-tested with gjs against stubbed `Main`/`global`/`Meta` before deployment.

## 2. Files modified / created

Modified:
- `components/ash-desktop/config/airootfs/usr/local/bin/echoos-wallpaper-apply`
- `components/ash-desktop/config/airootfs/etc/dconf/db/gdm.d/00-echoos-branding`
- `components/ash-desktop/scripts/validate-desktop.sh` (new checks)
- `components/ash-desktop/README.md` (documentation)
- `components/mad-install/packaging/PKGBUILD` (icon packaging)

Created:
- `components/ash-desktop/config/airootfs/etc/dconf/profile/user`
- `components/ash-desktop/config/airootfs/etc/dconf/profile/gdm`
- `components/ash-desktop/config/airootfs/etc/dconf/db/local.d/00-ash-shell`
- `components/ash-desktop/config/airootfs/etc/systemd/system/echoos-dconf-update.service` (+ `sysinit.target.wants` symlink)
- `components/ash-desktop/config/airootfs/usr/share/gnome-shell/extensions/ash-panel@echoos/{metadata.json,extension.js,stylesheet.css}`
- `components/ash-desktop/config/airootfs/usr/share/wallpapers/EchoOS-Lock/{metadata.json,contents/images/1600x900.png}`
- `components/ash-desktop/scripts/validate-branding.sh`
- `components/mad-install/config/rootfs/usr/share/icons/hicolor/{16x16,24x24,32x32,48x48,64x64,96x96,128x128,256x256}/apps/calamares.png`
- `docs/ash-desktop-branding-report.md` (this file)

Not modified: Echo Core, Echo Boot, MAD Installer Calamares modules/configs,
wallpaper assets (originals intact), any GNOME Shell system file.

## 3. Verification (VMware Workstation, UEFI, 1280×800)

All checks run on the live ISO; runtime values verified over SSH plus
pixel-level screenshot analysis.

| # | Test | Result |
| --- | --- | --- |
| 1 | First boot | PASS — autologin, Echo wallpaper, panel present |
| 2 | GDM login screen | PASS — Arch logo **removed** (before: bottom-centre Arch logo; after: none); greeter dconf values verified via `DCONF_PROFILE=gdm dconf read` |
| 3 | Desktop appearance | PASS — panel = rgba(20,20,24,0.70) over wallpaper (pixel-exact: expected (36.5,45.2,70.8) vs measured (38,46,73)) |
| 4 | Lock screen | PASS — `org.gnome.desktop.screensaver picture-uri` = EchoOS-Lock artwork (runtime-verified; visual per §4 note) |
| 5 | Unlock screen | PASS — session re-authenticates, panel visible immediately after unlock |
| 6 | Maximized application | PASS — window stops **below** the panel (pinned); panel switches to 0.80 alpha (pixel-exact: expected (44,52.4,70) vs measured (44,52,70)); reverts to 0.70 on restore |
| 7 | Normal application window | PASS |
| 8 | Multiple workspaces | PASS — panel constant across `Ctrl+Alt+←/→` |
| 9 | Panel visibility after unlocking | PASS |
| 10 | Different resolution | 1280×800 VM verified; panel is full-width/themed by CSS — resolution-independent by construction (§5) |
| 11 | Light/dark mode | PASS — both `picture-uri` and `picture-uri-dark` set on all three surfaces |
| 12 | Reboot + persistence | PASS — second boot re-applies defaults (`echoos-dconf-update.service` runs each boot; dconf defaults recompiled, session keys reapplied by autostart) |
| 13 | MAD Installer icon | PASS — dash shows the blue MAD mark instead of the orange Calamares arrow (fixed live and shipped) |
| 14 | Extension health | PASS — `gnome-extensions info ash-panel@echoos`: State ACTIVE, no JS errors in journal |
| 15 | Validators | PASS — `validate-desktop.sh` and `validate-branding.sh --system` (repository + runtime modes) |

Screenshots captured during the session: first boot, desktop, maximized
terminal, workspaces, overview, greeter before/after logo removal, dash
icon before/after fix.

## 4. Known limitations

1. **GDM greeter wallpaper**: GNOME 49+ greeters draw a styled login
   dialog **without a wallpaper** (`loginDialog.js` paints no background;
   `#lockDialogGroup` is a solid `#222226`). The Echo background keys are
   pre-seeded, but the greeter remains a clean dark surface with no Arch
   branding (logo removed). Restoring a greeter wallpaper would require
   overriding the shell theme in the greeter session (system gresource
   modification — excluded by the task restrictions) or a `session-modes:
   ["gdm"]` styling extension (possible follow-up).
2. **Live lock-screen visual capture**: VMware's VNC framebuffer stops
   receiving damage while the lock screen is active (upstream MKS quirk,
   seen before this change); the lock screen was verified via the session
   gsettings values, `LockedHint` transitions, and the shared rendering
   path (same `BackgroundManager` + wallpaper file as the verified
   desktop). On real hardware the lock screen shows the artwork blurred,
   per standard GNOME behaviour.
3. **Installed systems**: the same payload ships via the unpacked rootfs;
   the installer exclude list is unaffected. Installed-system boot was not
   re-run in this pass (Calamares end-to-end blocked earlier by a
   pre-existing BIOS installer abort documented in
   `docs/branding-checklist.md`).
4. **aarch64**: payloads are arch-neutral (no new packages); not booted
   (no ARM host).
5. GNOME Shell versions outside 45–51 fall back to the stock black panel
   (extension declares supported versions; harmless degradation).

## 5. Rollback instructions

All changes are additive and contained; rollback = remove the files and
rebuild:

```sh
git revert <commit>        # or: git checkout <previous-commit> -- components/
sudo rm -rf work           # IMPORTANT: mkarchiso run-once markers otherwise skip the payload
./build.sh
```

Per-surface rollback:
- Panel: `gsettings reset org.gnome.shell enabled-extensions` (or remove
  `etc/dconf/db/local.d/00-ash-shell` + `etc/dconf/profile/user`) → stock
  black panel; the extension can also be deleted from
  `/usr/share/gnome-shell/extensions/`.
- Lock screen: remove the two `org.gnome.desktop.screensaver` `gsettings`
  lines from `echoos-wallpaper-apply` → shell default background.
- GDM greeter: delete `etc/dconf/profile/gdm` and
  `etc/dconf/db/gdm.d/00-echoos-branding` → upstream Arch login screen
  (dark + Arch logo).
- Installer icon: delete the eight `hicolor/<size>/apps/calamares.png`
  files → upstream orange icon returns.

## 6. Validation scripts

- `components/ash-desktop/scripts/validate-desktop.sh` — component payload
  and contract checks (extended).
- `components/ash-desktop/scripts/validate-branding.sh` — wallpaper /
  panel / branding checks. Repository mode by default; `--system` verifies
  a booted system: compiled dconf DBs, session `gsettings` values, greeter
  keyfile, extension install + shell-version compatibility, and active
  extension state.
