# MAD Installer — Bug Log

Statuses: OPEN / FIXED / WONTFIX. Every entry lists evidence.

## BUG-001 — Summary page text unreadable (light-on-light) — FIXED
- **Found:** v1 install test, Summary page (screenshot
  `testing/screenshots/09-summary-v1-contrast-bug.png`).
- **Symptom:** the summary text area renders on the default light system
  palette while label text uses the dark-theme color — nearly unreadable.
- **Cause:** Calamares summary view lives in scroll-area viewports whose
  background follows the system palette; the v1 stylesheet only themed
  `#scrollAreaWidgetContents` (transparent) and `QLabel` (light text).
- **Fix:** stylesheet.qss v2 — `QAbstractScrollArea`/`QTextBrowser` forced
  onto `charcoal-900` + `text` tokens, inner container widgets transparent,
  broad `QWidget` color rule with explicit opaque-surface restores.
- **Status:** FIXED — **verified on screen** in ISO v3.

## BUG-002 — Partition page option-row text low contrast — FIXED (same change)
- **Found:** v1 install test, Partitions page (screenshot
  `testing/screenshots/05-installation-type-partitions.png`).
- **Symptom:** "Erase disk"/"Manual partitioning" description text renders
  dim against dark rows.
- **Fix:** broad QWidget text-color rule + explicit view backgrounds
  (stylesheet.qss v2).
- **Status:** FIXED — **verified on screen** in ISO v3
  (`testing/screenshots/05-installation-type-v2-readable.png`).

## BUG-003 — Stale Echo Install files carried into reused work/ tree — FIXED (process)
- **Found:** first MAD ISO boot — desktop showed the old "Install Echo OS"
  shortcut with the Calamares icon alongside MAD's.
- **Cause:** `mkarchiso`'s overlay step (`cp -a`) adds/overwrites but never
  deletes; the reused `work/x86_64/airootfs` still contained
  echo-install-era files (old branding dir, launcher, desktop entries).
  Compounded by mkarchiso's `work/base.*` stamp files silently skipping the
  whole build (exit 0, no ISO) until stamps are cleared.
- **Fix:** removed the stale files from the work tree + cleared stamps;
  rebuilt. **Process recommendation (OPEN, repo-level):** `build.sh` should
  detect component payload changes (or always clear `base._make_custom_*` /
  `_make_customize_airootfs` stamps) to avoid stale-overlay builds; today
  this is manual and error-prone.
- **Status:** FIXED for this build; process recommendation open.

## BUG-004 — Window title says "Echo OS Installer", not "MAD Installer" — WONTFIX (Calamares 3.4 constraint)
- Calamares derives the window title from the branding product name, which
  must remain "Echo OS" (the installed OS identity used across welcome text
  and module strings). MAD Installer identity is carried by the desktop
  launcher ("MAD Installer"), sidebar, slideshow, and artwork.
- Revisit with the independent engine (ROADMAP v2), which owns its own
  window title.

## BUG-005 — Slideshow title/hero overlap on tall slides — OPEN (cosmetic)
- **Found:** install progress screen (screenshot
  `testing/screenshots/10-installation-progress-slideshow.png`): the
  "MAD Installer" heading overlaps the hero mark's bounding box.
- **Impact:** cosmetic; all text remains legible.
- **Fix (planned):** anchor the mark below the title block with explicit
  offsets in `slideshow.qml`.

## BUG-006 — Host OOM kills the test VM during heavy install — NOT AN INSTALLER BUG
- Kernel log 02:01: `Out of memory: Killed process 48617 (qemu-system-x86)`.
- Mitigation: 3 GiB guest RAM + no concurrent heavy host work during tests
  (see ENVIRONMENT_REPORT.md).

## BUG-007 — Insufficient-disk check was non-blocking — FIXED (verified)
- **Found:** 5 GiB-disk VM test (screenshots
  `testing/screenshots/15-warning-not-enough-space.png`,
  `15-failure-insufficient-disk.png`).
- **Symptom:** the welcome page correctly warned "There is not enough drive
  space. At least 8 GiB is required." but **Next stayed enabled** — the
  inherited `welcome.conf` listed `storage` only under `check:`, not
  `required:`. The user could start a doomed install: the disk was
  partitioned and the install then failed at `unpackfs` with
  "rsync failed with error code 11".
- **Positive finding from the same test:** the failure is reported clearly
  ("Installation Failed"), the installer never claims success, and Calamares
  correctly shrank the layout (dropped swap) in its plan.
- **Fix:** `calamares/modules/welcome.conf` — `storage` added to
  `required:` so an undersized disk blocks progression at the welcome page.
- **Status:** FIXED — **verified on screen** on the v4 ISO
  (`testing/screenshots/16-storage-check-blocking.png`): the welcome page now
  states "Installation cannot continue", the indicator is an error icon, and
  **Next is disabled** on a 5 GiB disk. On a 40 GiB disk the check passes and
  Next is enabled (BIOS test run).

## BUG-008 — Prototype page overlays at real window size — FIX ROUND 2 — FIXED (pending re-verify)
- **Found:** user-annotated screenshots + live VMware pass on the 2026.10.31
  ISO (vnc-kbd.png): keyboard list clipped its 3rd row under the
  "Test your keyboard" label; the test field was overlapped by Back and
  Continue (field y = H-84 + height 40 ended below Back at H-64 — an
  overlap by construction); mode-page note at H-96 collided with the
  Custom card row; packages "Recommended" badges were right-anchored over
  the card names.
- **Root cause:** bottom clusters were bottom-anchored (`parent.height - N`)
  with deltas that only work for card heights ≥ 430 px, while the real
  card at windowSize 900x560 is ≈ 365-410 px depending on decorations.
- **Fix (welcomeq.qml):** every page's bottom cluster re-anchored with
  worst-case clearance — test label H-116, field H-96 (h34, ends H-62),
  Back H-52, Continue H-56 (h40); mode/packages cards compacted
  (72/40 px, rows at 82/48 px pitch, ends y≈268/248) with the note at H-84;
  keyboard list now Flickable (y=154, h = max(84, H-278), rows 36 px) so
  all 5 layouts stay reachable at any card height; remaining plain
  `Button` Continues converted to MadButton (accent style).
- **Status:** FIXED in source (qmllint clean); verification pass on the
  rebuilt ISO in progress.

## BUG-009 — Blank slideshow area during install — FIXED (rewritten)
- **Found:** user screenshot — the install progress page showed a white
  exec area where the slideshow should render.
- **Root cause:** the previous slideshow.qml used QML constructs the
  Calamares 3.4.2 slideshow engine rejects at load time.
- **Fix:** slideshow.qml rewritten with only proven-safe patterns — root
  Rectangle, `property int scene`, `Timer` 6000 ms cycling 3 scenes,
  opacity cross-fades with `Behavior`, `SequentialAnimation on rotation`,
  `RotationAnimation on rotation`, `SequentialAnimation on x`; no
  QtGraphicalEffects, no ScriptAction; qmllint 0 errors.
- **Status:** FIXED in source; render verification on the rebuilt ISO in
  progress.

## BUG-010 — VMware GUI power-on regression ("Cannot connect to the virtual machine")
- **Found:** 2026-11-01 test session — `vmrun start <vmx> gui` failed with
  "Cannot connect to the virtual machine"; the VMX itself starts fine
  (verified by foreground run).
- **Workaround:** start the VMware Workstation GUI (`vmware <vmx>`), then
  power on from the GUI with Ctrl+B — vmrun's GUI attach path is the broken
  part; `nogui` power-on also works. Boot order then needs the EFI Boot
  Manager (ESC during `bios.bootDelay`) to select the IDE CDROM when an
  earlier install occupies the disk.
- **Status:** NOT AN INSTALLER BUG — test-environment note.

## BUG-008 — VERIFIED FIXED (round 2, VMware live pass on 2026-11-01)
- Keyboard page: all rows render inside the flickable list, "Test your
  keyboard" label and test field clear of the list, Back/progress/Continue
  row clean (purple MadButton).
- Mode page: 2x2 cards compact, note clear below cards.
- Packages page: see BUG-011/012 below (badge + selection).
- Evidence: testing/screenshots/v2*-*.png (final-ISO pass).

## BUG-011 — Packages "Recommended" badge overlaid the card sub-text — FIXED
- **Found:** user screenshot on the 2026.10.31 ISO — the badge sat on top of
  "KDE Plasma" / "Firefox, Falkon" / "codecs, VLC".
- **Fix:** badge moved out of the text flow to the card's top edge
  (green corner pill, white fill, anchored top: -7) — name and sub-text no
  longer collide. **Verified on screen** (v24-packages-badge+selection.png).

## BUG-012 — Package cards were not clickable — FIXED (two bugs)
- **Found:** user report "i cant choose the another one".
- **Root cause 1:** the packages delegates had no MouseArea at all.
- **Root cause 2:** first click-handler version mutated the `chosen` JS
  object in place and reassigned the same reference — QML saw no property
  change, so the UI never updated.
- **Fix:** dedicated `toggle(name)` clones the object, flips the key,
  reassigns (fires change signals), and stores the selection in GlobalStorage
  ("packageGroups"). Recommended groups start selected.
  **Verified on screen:** click selects (purple border + soft fill),
  second click deselects (v24/v25 screenshots).

## BUG-013 — Slideshow still blank on the final ISO — ROOT CAUSE FOUND AND FIXED
- **Found:** install progress page white exec area on the 20:57 ISO, despite
  the BUG-009 rewrite.
- **Diagnosis (from the live guest's /root/.cache/calamares/session.log,
  read via the VM terminal):**
  `WARNING: QML component not ready: file:///.../slideshow.qml:133:47:
  Invalid property assignment: int expected`.
- **Root cause:** `font.pixelSize: 12.5` — a float assigned to an int
  property (same failure class as the earlier 11.5 case); qmllint does not
  flag int-coercion, only the Calamares QML engine rejects the whole file,
  leaving the exec area blank.
- **Fix:** 12.5 → 12; the two `border.width: 1.5` floats also normalized to
  2 for safety. qmllint clean.
- **Status:** FIXED in source; render verification on the rebuilt ISO.

## BUG-014 — VMware GUI power-on/window-attach regression — ENVIRONMENT NOTE
- `vmrun start <vmx> gui` → "Cannot connect to the virtual machine";
  GUI Ctrl+B worked once, then stopped; `vmware -x` flag ineffective.
  The VMX itself is healthy (foreground run OK, nogui start rc=0).
  Workaround: `vmrun start ... nogui` + VNC (127.0.0.1:5901). Test-host
  issue only, not an installer bug.

## DELIVERY — Pendrive
- Final ISO flashed to the user's 14.5 GB USB stick (/dev/sdb, chosen over
  the 119 GB USB disk), verified byte-for-byte with cmp against the ISO
  (VERIFY-OK). Stick shows ECHO_FOX_202610 + ARCHISO_EFI layout, UEFI+BIOS
  bootable.

## BUG-015 — Slideshow root cause confirmed and fixed (float 12.5 → 12)
- The 20:57 ISO's guest log confirmed `slideshow.qml:133:47: Invalid
  property assignment: int expected` — the exec area white-screen root
  cause. Fixed (12.5 → 12, plus the two border.width floats normalized).

## BUG-016 — Live desktop ignored the Echo OS wallpaper (xfdesktop monitor
naming) — FIXED
- **Found:** user report "the default wallpaper is not showing"; VMware
  live desktop still painted Xfce's built-in teal default.
- **Root cause:** the /etc/xdg xfce4-desktop factory default only matches a
  backdrop node named "monitor0"; xfdesktop names nodes after the real
  RandR output (Virtual1, VNC-0, HDMI-1, "default" ...). When no node
  matches, xfdesktop paints its own compiled-in default (xfce-teal) and
  never reads our wallpaper path.
- **Fix:** (a) new /usr/local/bin/echoos-wallpaper-apply + autostart entry —
  waits for xfdesktop's backdrop nodes, then points every last-image /
  image-style / image-show node at the Echo OS wallpaper (monitor-name
  independent, works live and installed); (b) all stock Xfce backgrounds
  removed from the payload (rm -rf /usr/share/backgrounds/xfce in
  customize_airootfs.sh) so the Echo OS wallpaper is the only choice.

## BUG-017 — Live medium booted via the Arch-branded syslinux BIOS menu — FIXED
- **Found:** photo from the user's test laptop: BIOS boot showing the Arch
  logo splash + "archlinux" header (stock archiso syslinux).
- **Fix:** the syslinux BIOS boot path is removed entirely — bootmodes is
  now UEFI-only ('uefi.systemd-boot' retained as the ESP builder), the
  syslinux overlay and package are dropped, and the customize stage
  replaces the systemd-bootx64.efi binary with rEFInd 0.14.1 so that
  EFI/BOOT/BOOTx64.EFI (ISO tree and efiboot.img ESP) is rEFInd; build.sh
  installs refind.conf / echoos.conf / fonts / icons into both trees.
- **Consequence (important):** the stick no longer boots legacy-BIOS-only
  machines. The laptop must boot in UEFI mode (boot menu "UEFI: <usb>").
  The installed system's bootloader is unchanged (rEFInd on UEFI installs,
  GRUB on BIOS installs done from earlier media).

## FINAL VERIFICATION PASS — 22:43 ISO (all fixes) — PASS
Verified in VMware (VNC captures, guest truthfully rendering; note the
host-side VNC tile-cache corruption seen mid-run is a VMware RemoteDisplay
artifact — repaired regions around the mouse always showed correct guest
content):
1. Boot: firmware offers "rEFInd Boot Manager"; the live medium boots
   through rEFInd only ("rEFInd - Booting OS / Starting vmlinuz-linux /
   archisobasedir=arch ..."). No syslinux menu, no systemd-boot menu,
   no Arch branding anywhere in the boot path. ISO /boot/syslinux removed;
   EFI/BOOT/BOOTx64.EFI = rEFInd 0.14.1 in ISO tree and ESP.
2. Live desktop: the blue Echo OS wallpaper renders (previously the Xfce
   teal default / black). LightDM greeter background = the same wallpaper
   (verified on the installed system's greeter).
3. Installer flow: all MAD pages clean, packages selection toggles.
4. Install: exec area shows the LIVE animated slideshow — scene with the
   purple cube, orbit rings, rotating satellite card, "Meet MAD Installer"
   caption — while "Filling up filesystems" runs at 25%.
5. Finished: "Welcome to a New Experience" + Restart Now / Continue
   Testing.
Screenshots: testing/screenshots/ (vnc-refind*, vnc-live6, vnc-slide*,
vnc-flow*).

## LAPTOP REPORT — "after installing it shows only live environment, not
the user" — ANALYSIS
- The installed system itself is correct: it creates the chosen user
  (verified twice in VMware — SDDM/LightDM lists the user, login works),
  autologin and all live-only config are excluded from the install
  (unpackfs exclude-list drops /etc/lightdm/lightdm.conf.d/,
  /home/archiso, live systemd units), and the installed system's greeter
  shows the Echo OS wallpaper.
- The laptop symptom is the firmware booting the USB stick again instead
  of the internal disk: HP firmware keeps USB first in boot priority, so
  after "Restart Now" the machine lands back in the live environment
  (which autologins as the Live user — no password, no created user).
- Action for the user: remove the USB stick as soon as the install
  finishes (before/at "Restart Now"), or open the laptop's boot menu
  (Esc/F9 on HP) and pick the internal drive. The stick must also boot in
  UEFI mode on this media (the BIOS syslinux path was removed).
