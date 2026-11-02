# MAD Installer — Migration Notes

## From Echo Install to MAD Installer

### What was copied

`components/echo-install` → `components/mad-install` (Phase 2), byte-identical,
permissions preserved (`docs/COPY-VERIFICATION.md`). The original
`echo-install` component is untouched and remains the ISO's active installer
until Phase 9 integration.

### What changed (identity only — engine behavior identical)

| Area | echo-install | mad-install |
| --- | --- | --- |
| Component name | `echo-install` | `mad-install` |
| Calamares branding | `branding/echoos` (`componentName: echoos`) | `branding/mad` (`componentName: mad`) |
| Installer name in UI | "Echo OS Installer" | "MAD Installer" (+ "Powered by Echo OS") |
| Product strings | hardcoded `2026.10.29` | pinned to os-release (`Echo OS 2.0 (Fox)`, `2.0`) |
| Artwork | echoos-logo.png + upstream Calamares assets (banner, squid, languages, + .license) | only Echo OS mark derivatives from master `echo-mark.svg` (+ white contrast variant); no upstream assets |
| Stylesheet | stock, commented out | full MAD theme (docs/DESIGN-TOKENS.md) |
| Slideshow | stock show.qml + productWelcome | MAD slideshow.qml (3 slides, factual) |
| Launcher | `echoos-install-launcher` | `mad-installer-launcher` (log: `/tmp/mad-installer-launcher.log`) |
| xcb wrapper | `echoos-calamares` | `mad-installer-x11` (comment corrected; unused fallback, F2) |
| Boot finalize | `echoos-refindconf-write` / `echoos-refind-sync.hook` | `mad-refindconf-write` / `mad-refind-sync.hook` |
| Desktop entry | `echoos-install.desktop`, `Icon=calamares` | `mad-installer.desktop`, `Icon=mad-installer` (hicolor icon shipped) |
| Log upload | fiche → termbin.com | **disabled** (`uploadServer: none`) — installer logs must not go to public pastebins |
| Window | 800×520 | 1024×640, same centering policy |

### What intentionally did NOT change

- Module sequence in `settings.conf` (except `branding: mad`).
- All 18 module configurations (partition/mount/fstab/users/locale/keyboard/
  displaymanager/services-systemd/shellprocess*/unpackfs/...).
- `unpackfs/exclude-list.txt` semantics (MAD's own file names substituted).
- polkit rule mechanics (`io.calamares.calamares.pkexec.run` + generic
  `org.freedesktop.policykit.exec` for the live user).
- OS-level identity: installed system remains **Echo OS** (boot entries
  "Echo OS", `/var/log/echoos-bootloader.log`, SDDM theme `echoos`).

### Build integration (Phase 9, after validation)

1. `build/config/components.tsv`: add
   `40  mad-install  components/mad-install  echo-core,echo-boot,echo-desktop`
   and drop the `echo-install` row (component files stay in the repo).
2. `build/config/overlays.tsv`: same four overlay rows with
   `mad-install` as component.
3. `build/config/legacy-file-owners.tsv` / `legacy-package-owners.tsv`:
   re-point `INSTALLER` rows to the mad-install paths (documented change).
4. `build/validate.sh`: update installer checks to the MAD names
   (`branding: mad`, `mad-installer-launcher`, `mad-refindboot` instance,
   desktop entry) — outside the component, documented per rule 15.
5. Both installers must never be assembled into one profile (duplicate
   desktop entries, duplicate polkit rules, duplicate hooks).

### Rollback

Revert the Phase 9 build-config changes; `echo-install` is byte-identical to
its pre-MAD state (verified by git), so rollback is a config edit, not a
code restoration.

## Calamares replacement strategy (summary)

See `ROADMAP.md` v2 and `ARCHITECTURE.md` §5/§7. Strategy: introduce an
Installation API shimmed over Calamares first, replace capabilities one at a
time (payload, disk, boot), and only claim engine independence when the
Calamares runtime, libraries and modules are gone.
