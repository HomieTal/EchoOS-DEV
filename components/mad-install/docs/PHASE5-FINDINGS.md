# Phase 5 Findings — backend verification items (MAD Installer)

Collected during Phases 1–3; to be resolved with VM evidence in Phase 5.
Nothing here changes install behavior until resolved and documented.

## F1 — Which branding path does Calamares 3.4.2 actually search?

**RESOLVED (VM evidence, 2026-10-31, screenshot
`docs/phase5-vm-evidence/01-echo-branding-etc-calamares.png`):**

The audited `echoos-fox-2026.10.29-x86_64.iso` was booted in a UEFI QEMU VM
(OVMF, 4 GB RAM, disposable 40G qcow2). The live session auto-started
Calamares and the window came up **fully branded from
`/etc/calamares/branding/echoos`**: "Echo OS Installer" window title,
"Welcome to the Echo OS Fox 2026.10.29 installer" welcome text, the Echo OS
mark as sidebar logo and welcome image, and the branded sidebar colors.

Conclusion: `docs/branding-checklist.md`'s claim that Calamares 3.4.2
"ignored" `/etc/calamares/branding` is **stale**. The overlay path
`calamares → airootfs/etc/calamares` is correct, and MAD's
`branding/mad` component at the same path will load. No extra
`/usr/share/calamares/branding` overlay row is needed. The stock `default`
branding under `/usr/share/calamares/branding` (shipped by the calamares
package) is not what loads — the local `branding: mad` selection wins.

## F2 — `mad-installer-calamares` xcb wrapper has no caller

**RESOLVED (same VM session):** the live session launched Calamares through
`mad-installer-launcher` → `pkexec /usr/bin/calamares` (the wrapper is not
in the launch path) and the installer window rendered correctly in the
Plasma Wayland live session. The current launch path is proven; Qt falls
back to XWayland/xcb through the launcher's `xhost +SI:localuser:root`
grant. The wrapper is retained as documented fallback code (validated to
exist by `validate.sh`), and the misleading "the launcher escalates to this
wrapper" comment was corrected.

## F3 — BIOS boot path

**RESOLVED (static evidence, `shellprocess-refindboot.conf` +
`mad-refindconf-write`):**

- **UEFI:** rEFInd installed to the ESP (mounted at `/boot` by the partition
  module), `--alldrivers`, removable-media fallback published, kernel +
  initramfs copied to the ESP root, manual `refind.conf` with `root=UUID=`.
- **BIOS (x86_64 only):** GRUB is installed to the MBR of the target disk
  (`grub-install --recheck` on the disk derived from the bind-mounted root)
  and `grub-mkconfig` generates `/boot/grub/grub.cfg`. The `grub` package is
  shipped in the live image by echo-boot. Non-x86_64 firmware explicitly
  errors out.

Documentation updated: the README now states UEFI→rEFInd / BIOS→GRUB (x86_64)
instead of implying rEFInd handles both. VM confirmation of an actual BIOS
install remains a Phase 8 test case.

## F3 — BIOS boot path

**RESOLVED (static evidence, `shellprocess-refindboot.conf` +
`mad-refindconf-write`):**

- **UEFI:** rEFInd installed to the ESP (mounted at `/boot` by the partition
  module), `--alldrivers`, removable-media fallback published, kernel +
  initramfs copied to the ESP root, manual `refind.conf` with `root=UUID=`.
- **BIOS (x86_64 only):** GRUB is installed to the MBR of the target disk
  (`grub-install --recheck` on the disk derived from the bind-mounted root)
  and `grub-mkconfig` generates `/boot/grub/grub.cfg`. The `grub` package is
  shipped in the live image by echo-boot. Non-x86_64 firmware explicitly
  errors out.

Documentation updated: the README now states UEFI→rEFInd / BIOS→GRUB (x86_64)
instead of implying rEFInd handles both. VM confirmation of an actual BIOS
install remains a Phase 8 test case.
