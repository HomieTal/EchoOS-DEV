Echo OS local package repository
================================

This directory holds packages for the `[echo]` repository, which is
configured in `profile/pacman.conf.in` via the `scripts/render-pacman-conf.sh`
helper.

Contents
--------
- `calamares-3.4.2-2-x86_64.pkg.tar.zst`  — Graphical installer
- `PKGBUILD`                                — Build recipe (source of truth)
- `echo.db.tar.zst`                         — pacman repository database
- `echo.files.tar.zst`                      — pacman repository files database

The PKGBUILD is based on the Arch Linux AUR PKGBUILD for calamares with
module selection tuned for this live ISO. The built package has had
modules that conflict with the chosen strategy (dracut, initramfs,
packagechooser, etc.) skipped at build time via CMake.

Updating the repository database
--------------------------------
After adding or replacing packages:

    repo-add packages/echo.db.tar.zst packages/*.pkg.tar.zst

Regenerate the profile pacman.conf
----------------------------------
The profile uses `profile/pacman.conf.in` with the placeholder
`@LOCAL_REPO_PATH@` expanded to the absolute path of this directory:

    ./scripts/render-pacman-conf.sh

License
-------
The PKGBUILD metadata and this repository structure are project artifacts.
The calamares package itself is GPL-3.0-or-later.
