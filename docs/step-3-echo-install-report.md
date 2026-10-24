# Step 3 report — Echo Install separation

Status: **Step 3 complete.** Calamares configuration, modules, unpackfs exclude list, live polkit rule, PKGBUILD, and package manifests exist under `components/echo-install/`. No profile files were moved or modified. profile/ and Echo Boot remain unchanged. No ISO built, no boot/install tests. Profile parity is **not established**.

## Files migrated

| Component path | Source | Profile dest | Notes |
| --- | --- | --- | --- |
| calamares/settings.conf | profile/airootfs/etc/calamares/settings.conf | airootfs/etc/calamares/settings.conf | Module order preserved |
| calamares/modules/*.conf (16) | profile/airootfs/etc/calamares/modules/*.conf | airootfs/etc/calamares/modules/*.conf | unpackfs/mount/fstab/locale/keyboard/users/initcpiocfg/initcpio/displaymanager/services/shellprocess/packages/bootloader/welcome etc. |
| calamares/modules/unpackfs/exclude-list.txt | profile/airootfs/etc/calamares/modules/unpackfs/exclude-list.txt | airootfs/etc/calamares/modules/unpackfs/exclude-list.txt | Live/target boundary preserved |
| config/live/polkit-1/rules.d/50-calamares.rules | profile/airootfs/etc/polkit-1/rules.d/50-calamares.rules | airootfs/etc/polkit-1/rules.d/50-calamares.rules | LIVE-EXCLUDED |
| packages/PKGBUILD | packages/PKGBUILD | - | Recipe |
| packages/calamares-3.4.2-2-x86_64.pkg.tar.zst | packages/calamares-3.4.2-2-x86_64.pkg.tar.zst | - | Artifact copied to component and build/repo |
| packages/packages.x86_64 | manifest | - | [calamares] |
| packages/packages.aarch64 | manifest | - | [] |

## Calamares behavior
- Version: 3.4.2 (PKGBUILD)
- Module sequence preserved in settings.conf; instances for shellprocess@sysusers/@cleanup preserved
- Offline unpackfs (no package downloads); packages.conf is no-op
- sysusers before users; removeuser before users; unpackfs + mount/fstab/initcpiocfg/initcpio; displaymanager lightdm; services-systemd; cleanup removes calamares/mkinitcpio-archiso/livecd-sounds and refreshes db (best-effort)
- Target bootloader: GRUB via bootloader.conf (grub-install/mkconfig)
- Branding: stock default (empty branding dir)
- Locale/keyboard/users/password policy preserved
- Exclude list unchanged

## Packages
- x86_64: 1 (calamares)
- aarch64: 0

## Validation
Command: ./build/validate.sh
Results: see log. Boot manifests unchanged. profile/ unchanged (baseline). No ISO/boot/install tests.

## Profile/Echo Boot unchanged
Confirmed: no files modified in profile/; Echo Boot payloads/manifests unchanged.

## Outstanding blockers
- Echo Core payload not populated
- Shared templates missing from build/template/
- Assembly stub blocked

## Rollback
Remove echo-install payloads, build/repo artifact copy if desired, revert validator/docs changes; no profile changes needed.

No ISO built, no boot/install tests performed.
