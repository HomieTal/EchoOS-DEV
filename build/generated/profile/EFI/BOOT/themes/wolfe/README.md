# Wolfe rEFInd Theme — Echo OS adaptation

Echo Boot's visual identity is based on the Wolfe rEFInd theme, retrieved as
`refind-wolfe-main.zip` (no repository URL is recorded in the archive), which
is itself built on
[refind-minimal](https://github.com/EvanPurkhiser/rEFInd-minimal/) and
[refind-black](https://github.com/anthon38/refind-black/). The Wolfe theme is
MIT-licensed; `LICENSE` in this directory is the upstream license, preserved
verbatim.

## What this adaptation changes

The upstream visual design is retained: flat accent background, release
wordmark centred in the upper third, animal artwork anchored bottom-right,
white glyph icons with a hard navy shadow, black selection panel with green
accent, hidden labels/hints/arrows/badges.

Changes for Echo OS:

1. **Wordmark.** The upstream background ships the theme author's "Wolfe"
   wordmark. The boot interface must not display external repository-owner
   branding, so `release/background.png` re-renders the wordmark region as
   "Echo OS" (same position, colour `#E8E8E8`, soft `#211360` shadow). The
   animal artwork is the upstream `background.png` used **verbatim** —
   pixel-identical right of x=1200.
2. **Paths.** `theme.conf` points at `themes/wolfe/...` relative to the
   rEFInd binary directory (`EFI/BOOT` on the ESP and the ISO 9660 tree),
   and the banner at the per-release `release/background.png`.
3. **Icons.** The 29 upstream icons ship unmodified. Two Echo additions
   follow the same visual language (white glyph, `#211360` hard shadow):
   - `icons/os_echo.png` — the Echo "e" mark (brand geometry from the
     Calamares `echo-mark.svg`), used by the Echo OS boot entries.
   - `icons/func_firmware.png` — gear glyph for the `firmware` tool, which
     the upstream set does not provide (upstream `showtools` omits it).

## Release procedure (animal releases)

Only `release/` changes between releases; the rEFInd configuration, layout
and icon set stay identical. See `release/release.conf` for the checklist.
Current release: **Fox** (ships the upstream Wolfe artwork verbatim).

## Upstream README (retained for reference)

This is a custom theme for [rEFInd](http://www.rodsbooks.com/refind/), an
easy to use boot manager for EFI based systems. It's currently based on
[refind-minimal](https://github.com/EvanPurkhiser/rEFInd-minimal/) for most
base stuff, and [refind-black](https://github.com/anthon38/refind-black/)
for the base icons, with some shadows and details added.

Entries that are autodetected show the proper icons from this theme where
available; rEFInd falls back to the default `icons/` directory otherwise.
