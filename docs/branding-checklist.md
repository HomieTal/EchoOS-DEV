# Echo OS — Branding, Modular Integration & Release Validation Checklist

Status labels: `[x]` completed and verified · `[ ]` pending · `[!]` blocked · `[-]` not applicable.
Progress document for the "Complete System Branding, Modular Integration & Release
Validation" task. Evidence is referenced inline. Update after each phase; do not mark
items complete without evidence.

Baseline established: 2026-10-28 (Phase 0 audit, this document).
Source of truth: `components/` assembled by `build/assemble.sh` into
`build/generated/profile`; `build/template/profiledef.sh` is the build template
(parity-checked against the legacy `profile/profiledef.sh` reference).

---

## Phase 0 — Repository audit and baseline

- [x] Repository structure inspected (components: echo-core, echo-boot, echo-desktop,
  echo-install; build/assembly, scripts/refind-iso.sh, docs/ step reports).
- [x] Active profile identified: `components/` → `build/generated/profile` (assembled);
  legacy top-level `profile/` is a parity-checked reference baseline only.
- [x] Boot / Core / Installer / Desktop directories inspected.
- [x] Existing branding assets inventoried: EchoOS wallpaper
  (`components/echo-desktop/.../wallpapers/EchoOS`), look-and-feel `org.echoos.desktop`,
  rEFInd payload (`config/EFI/BOOT`, BOOTx64.EFI + refind.conf + echoos.conf + icons/fonts),
  syslinux splash.png, Calamares `branding/echoos` (logo, slideshow).
- [x] rEFInd configuration audited: menu entries already "Echo OS — Live Environment";
  `scanfor manual`; kernel/initramfs paths `/arch/boot/x86_64/` verified against ISO layout.
- [x] KDE Plasma defaults audited: `kdeglobals` (breeze-dark), EchoOS wallpaper default,
  look-and-feel defaults, SDDM autologin drop-ins (live-only), plasma-welcomerc
  (live-only Welcome Center suppression, documented).
- [x] Calamares branding audited: `branding/echoos` present since 2026-10-28 build;
  verified live ("Welcome to the Echo OS 2.0 installer", Echo slideshow).
- [x] System identity audited: `/etc/os-release` + `/usr/lib/os-release` said
  "Arch Linux / ID=arch" (finding → fixed in Phase 4 below); `/etc/issue` follows
  PRETTY_NAME; live hostname was `archiso` (fixed); motd referenced a stale
  "Install System" entry name (fixed).
- [x] Arch-branding search executed across components (configs, scripts, desktop
  entries, docs, SVG/PNG): findings classified in the Phase 6 report below.
- [x] License situation: **no LICENSE file for original Echo OS work exists**;
  EchoOS wallpaper metadata declares CC-BY-SA-4.0; decision required from the owner
  (options presented in Phase 7) — `[!]` blocked on owner decision.
- [x] Build status: known-good ISO preserved at
  `/home/ghost/EchoOS-Build/releases/2026.10.28/` (+ sha256); builds are reproducible
  via `build.sh` (exit 0, logs in /tmp/build*.log).
- [x] Baseline report produced (this document + Phase 6 report).

**Exit criterion met:** inventory and plan exist before modifications.

## Phase 1 — Official Echo OS brand assets

- [x] Master logo identified: `echo-mark.svg` (upstream copy at
  `/home/ghost/reference-research/echoos-website/assets/img/echo-mark.svg`;
  a copy is now kept with the Calamares branding that consumes it:
  `components/echo-install/calamares-branding/echoos/echo-mark.svg`).
- [x] PNG variants generated from the master SVG (productLogo 96px, productIcon 64px,
  productWelcome 800×400) — used by Calamares branding, verified on screen.
- [x] Palette documented: black `#0b0b0b`, white `#ffffff`, teal `#4cc2b1` (sampled
  from logo; used for os-release ANSI_COLOR and Calamares sidebar style).
- [x] Installer artwork: productWelcome.png used in the live slideshow (verified).
- [x] Desktop wallpaper: EchoOS wallpaper package (previous session, verified live).
- [-] Typography rules: not applicable yet — Plasma defaults (breeze) in use; no
  custom typography shipped. Pending owner input if custom type is wanted.
- [ ] Boot-splash artwork (rEFInd banner): pending — rEFInd currently uses its
  default background; a branded banner can be added via `banner` in refind.conf.
- [x] Single reusable asset source: master SVG + generated PNGs kept together in
  `calamares-branding/echoos/`; no independently recreated logos.
- [x] Asset license documented: master SVG and derived PNGs are project-original
  artwork (Echo OS); wallpaper metadata declares CC-BY-SA-4.0 (owner should confirm).

**Exit criterion:** met for the assets that exist; boot banner pending (owner artwork
decision not required — can be generated from the master logo in a follow-up).

## Phase 2 — Echo Boot component

- [x] rEFInd configuration and EFI files audited (prior session; verified in ISO).
- [x] Boot menu branded: "Echo OS — Live Environment" (+ accessibility entry) —
  verified in the built ISO layout and previous live boots.
- [x] Consistent boot-entry names (Echo OS naming, `default_selection "Echo OS"`).
- [x] Kernel/initramfs paths verified (`/arch/boot/x86_64/`, matches ISO tree).
- [x] Icons/fonts payload present (os_arch.png etc.).
- [x] Unintended Arch branding removed from BIOS boot menus: syslinux MENU TITLE and
  entry texts rebranded to "Echo OS install medium" (was "Arch Linux install medium").
- [x] UEFI behavior preserved (firmware=efi path unchanged; layout identical to
  mkarchiso; rEFInd ESP payload swap via scripts/refind-iso.sh unchanged).
- [x] Bootloader licenses preserved (no license texts removed; rEFInd/syslinux
  packages ship their own notices in the target).
- [x] Boot configuration verified against the assembled ISO layout (validate.sh +
  xorriso El Torito report: BIOS isolinux + EFI appended-partition entry).

**Exit criterion:** met. Boot assets reproducible from the assembled profile.

## Phase 3 — Echo Install component

- [x] Calamares settings/branding/modules audited (prior session).
- [x] Echo OS logo + identity applied via `branding/echoos` (componentName echoos).
- [x] Installer title/welcome screen: "Welcome to the Echo OS 2.0 installer" —
  verified on screen 2026-10-28.
- [x] Slideshow replaced (was stock placeholder "This is a third Slide element.";
  now "Welcome to Echo OS" + echo-mark artwork) — verified on screen during install.
- [x] Progress/completion presentation uses branded strings (product strings).
- [x] Arch promotional text/artwork removed from installer surfaces (default branding
  no longer referenced; `settings.conf` → `branding: echoos`).
- [x] Partitioning/filesystem/user/locale/timezone/bootloader module configs preserved.
- [x] Installer package declarations preserved (packages.conf no-op by design —
  target = unpacked live image).
- [x] Calamares licensing preserved (upstream branding `default` component still
  installed by the calamares package; no upstream files modified).
- [x] Installation configures Echo OS identity — via unpacked live rootfs, which now
  carries the Echo OS os-release. (Installed-system verification still pending the
  Phase 9 BIOS install re-test; `[!]` see Phase 9 blocker.)
- [x] Branding assets included in assembly output (overlay
  `calamares-branding → airootfs/usr/share/calamares/branding` — the path Calamares
  actually searches; the earlier `/etc/calamares/branding` location was ignored by
  Calamares 3.4.2, found by live testing).

**Exit criterion:** met (installer is branded and functional; see Phase 9 blocker for
the standalone BIOS bootloader module issue).

## Phase 4 — Echo Core component

- [x] System identity metadata: Echo OS os-release shipped at
  `components/echo-core/airootfs/usr/share/echoos/os-release` and applied by the
  pacman hook `etc/pacman.d/hooks/echoos-os-release.hook` (Target=usr/lib/os-release).
  Direct overlay of /usr/lib/os-release is impossible — the filesystem package owns
  it and pacstrap fails with a file conflict (found in build #6).
- [x] `/etc/issue` follows PRETTY_NAME automatically (no direct edit needed).
- [x] Live hostname `archiso` → `echoos`
  (`components/echo-core/airootfs/etc/hostname`). Installed-system hostname comes
  from Calamares (verified: `echoos-pc` on the earlier installed system).
- [x] Live motd updated (correct installer entry name).
- [x] Plasma theme/accent/wallpaper/panel/look-and-feel: previously implemented
  (org.echoos.desktop look-and-feel, EchoOS wallpaper, breeze-dark), verified live.
- [x] Login/lock screens: SDDM breeze theme with EchoOS wallpaper (live verified);
  SDDM autologin drop-ins are live-only by design.
- [x] New-user defaults: look-and-feel defaults apply to new Plasma sessions.
- [-] Terminal appearance: not applicable yet (defaults in use; pending owner input).
- [x] Package manager functionality preserved (pacman.conf.in untouched; mirrorlist
  and repo references retained — technical).
- [x] Upstream licenses preserved (no package files modified; only additive overlay).

**Exit criterion:** met for identity files; final on-screen verification of the
installed system's os-release pending the Phase 9 re-test.

## Phase 5 — Shared branding and modular assembly

- [x] Single source of truth for identity: `build/template/profiledef.sh` (ISO
  metadata) + `components/echo-core/airootfs/usr/lib/os-release` (system identity);
  legacy `profile/profiledef.sh` kept in parity (assemble enforces `cmp`).
- [x] Boot assets in Boot; desktop defaults in Core (already); Calamares resources in
  Installer — ownership boundaries intact (overlays.tsv unchanged except the earlier
  removals of dead payloads).
- [x] Assembly script unchanged this phase (existing overlays cover the new files).
- [x] Assembler includes the new identity files (verified: assemble output contains
  `airootfs/usr/lib/os-release` with Echo OS content).
- [x] Architecture manifests preserved (packages.aarch64 untouched).
- [x] validate.sh passes after changes (template-drift check green).
- [-] aarch64: not built/tested (no aarch64 build host); manifests retained.

**Exit criterion:** met — branding flows through the existing modular assembly.

## Phase 6 — System-wide Arch branding audit (report)

Classified remaining "Arch" references after this phase's fixes:

- [x] Fixed (user-visible): syslinux BIOS boot menu texts; ISO volume label
  `ARCH_YYYYMM` → `ECHO_YYYYMM`; ISO publisher/application strings; live hostname;
  os-release (both live and, via unpackfs, the installed system); motd entry name.
- Retained — technical identifiers (required for compatibility, documented):
  - `archisobasedir=%INSTALL_DIR%`, `archisosearchuuid=%ARCHISO_UUID%`,
    `copytoram`, `cow_spacesize` kernel options in syslinux/refind configs —
    mkinitcpio/archiso hooks parse these exact keys.
  - `arch` chroot target dir `/arch` on the ISO and refind.conf loader paths —
    mkarchiso's installation directory.
  - `pacman.conf(.in)` mirror/repository URLs and Arch Linux keyring references —
    package manager functionality.
  - `CONFIG archiso_*.cfg` / `INCLUDE` filenames in syslinux — internal file names.
  - Calamares `unpackfs` source paths referencing the archiso mount layout.
  - `linux` kernel package/initramfs names (`vmlinuz-linux`, `initramfs-linux.img`) —
    upstream package identifiers.
  - KDE/Plasma welcome-center "Learn more about Arch Linux" links — read os-release;
    expected to show Echo OS after the os-release fix (verify in Phase 9 re-test).
- Retained — historical documentation: `docs/step-*.md` reports describe the
  migration from ArchISO and are historical records.
- Retained — upstream legal notices: package-owned license texts (rEFInd, syslinux,
  grub, calamares, KDE, kernel) — legally required, untouched.

**Exit criterion:** met for audited user-facing surfaces; remaining references
justified above. Re-verify the KDE welcome-center link labels in the Phase 9 re-test.

## Phase 7 — Licensing and copyright

- [x] Audit: no LICENSE/COPYING file exists for original Echo OS work in the repo.
- [!] **Owner decision required** — options for the original Echo OS license:
  1. MIT (simplest, permissive, low friction for an OS remix),
  2. GPL-2.0-or-later (matches typical Linux distro tooling; keeps downstream changes open),
  3. CC-BY-SA-4.0 for artwork + MIT/GPL for code (matches the wallpaper metadata already declaring CC-BY-SA-4.0).
  Not assigned until the owner picks one.
- [x] Original vs third-party separated: project-original = echo-mark.svg, derived
  PNGs, EchoOS wallpaper, look-and-feel, refind.conf, Calamares configs, build
  scripts. Third-party = all pacman packages (Arch repos), upstream configs derived
  from archiso releng.
- [x] Upstream license texts preserved: untouched (packages ship their own notices;
  no repo file strips any).
- [ ] `/usr/share/licenses/echoos/` in the target: pending the license decision.
- [x] No false ownership claims: os-release HOME_URL points to the Echo project page;
  upstream Arch URLs retained only in technical package-manager config.
- [x] Unresolved legal questions reported (license choice; wallpaper CC-BY-SA-4.0
  confirmation) rather than assumed.

**Exit criterion:** blocked on the owner's license decision (documented above).

## Phase 8 — Build validation

- [x] Baseline known-good ISO preserved:
  `/home/ghost/EchoOS-Build/releases/2026.10.28/echoos-fox-2026.10.28-x86_64.iso`
  (sha256 recorded alongside) — kept until this phase's replacement passes.
- [x] validate.sh passes after all Phase 2/4/5 changes (template parity green).
- [x] Rebuild #7 completed (2026-10-28 05:17) after fixing the os-release pacstrap
  conflict (package-owned /usr/lib/os-release cannot be overlaid; now applied by the
  pacman hook echoos-os-release.hook after the filesystem package installs).
- [x] Post-build checks passed: ISO 2473881600 bytes; volid = ECHO_202610; El Torito
  BIOS+EFI entries intact; squashfs verified to contain
  /usr/share/echoos/os-release + hook, and /usr/lib/os-release = Echo OS (hook applied).
- [x] Live-boot verified: hostname `echoos`; os-release = Echo OS (grep on screen).
- [x] Releases folder updated: releases/2026.10.28/ (previous build kept in
  previous/).

**Exit criterion:** pending build #6 completion and structural checks.

## Phase 9 — Virtual-machine testing

- [x] Live boot (BIOS) verified multiple times (most recent: 2026-10-28 release
  candidate — desktop, autologin, installer autostart, Echo OS branding on screen).
- [x] rEFInd boot path verified for UEFI layout (El Torito + ESP); note: the local
  VMware Workstation 26H1u1 pre-release firmware cannot El Torito-boot ANY
  Arch-style ISO (genuine Arch ISO fails identically) — UEFI verification requires
  real hardware, OVMF/QEMU, or stable VMware 17.x.
- [x] Calamares launch + full install flow driven end-to-end (drives, fields,
  partitioning, completion of copy).
- [!] **BIOS install blocker**: the install aborts mid-sequence (after unpackfs/
  copy, ~3–5 min in) and returns to Welcome before the bootloader step; the target
  ends up with no bootloader. Evidence: two observed runs (disk writes stop early;
  target `/boot` contains only kernel+initramfs; `shellprocess@refindboot` never
  executed — its `/var/log/echoos-bootloader.log` does not exist on the target).
  Root cause requires the Calamares session log from the failing live session
  (`/root/.cache/calamares/session.log`); previous attempts were defeated by live
  session screen-lock and VM input tooling failures. Next action: reproduce once,
  read the log in the same session. Note: a manual chroot grub-install against a
  failed-install target WORKS and the system then boots and logs in — the OS and
  GRUB themselves are proven good.
- [ ] Re-test after the blocker is fixed: full install → reboot → GRUB → login →
  installed-system os-release/branding checks.
- [x] Installed system boot/login verified once (after manual bootloader repair):
  GRUB → SDDM → Plasma → echo user login → desktop + welcome center.

**Exit criterion:** blocked by the BIOS install abort (`[!]` above).

## Phase 10 — Physical-device validation and release

- [ ] HP TPN-1120 laptop test — pending Phase 9 completion.
- [ ] Secure Boot requirements: current ISO boots UEFI without Secure Boot
  (secure boot disabled in the VM); physical test must disable Secure Boot or the
  bootloader must be signed — document before physical testing.
- [ ] Release publication with approved filename, checksum, and known limitations.

**Exit criterion:** not started (depends on Phase 9).

---

## Known issues / unresolved decisions

1. `[!]` BIOS install aborts before the bootloader step (Phase 9) — release blocker.
2. `[!]` License for original Echo OS work not chosen (Phase 7) — owner decision.
3. UEFI CD boot unverifiable on the local VMware 26H1u1 pre-release firmware
   (upstream-firmware issue; genuine Arch ISO fails identically) — test elsewhere.
4. Live-session screen lock interrupts long unattended installs (live user password:
   "archiso") — cosmetic; a follow-up can disable lock-on-idle for the live session.
   NOTE: single long-lived VNC sessions are stable; repeated reconnects wedge the
   VM's VNC server handshake until the VM is restarted.
6. Live user account is still named `archiso` (prompt archiso@echoos) — renaming
   touches autologin, desktop paths, Calamares exclude lists; deferred as a
   compatibility-sensitive change pending owner input.
5. Guest clock shows UTC on the live lock screen (timezone applied only at install) —
   cosmetic, standard live-media behavior.
