# Echo OS — SPD Core Rebranding + Universal BIOS/UEFI Boot Compatibility

Status: **implemented and verified on the generated ISO**
(`out/echoos-fox-2026.11.04-x86_64.iso`, version id 2026.11.04; the previous
working ISOs 2026.11.02 / 2026.11.03 are untouched).
Pre-change backups: `/home/ghost/EchoOS-Build/backups/2026-11-04-pre-spdc-bios/`.

---

## 1. SPD Core branding (PART 1)

Distinction kept everywhere: **distribution = Echo OS**, **core subsystem =
SPD Core**, desktop identity unchanged (Ash Desktop).

| Change | File |
| --- | --- |
| Live hostname `echoos` → **`spd`** | `components/echo-core/airootfs/etc/hostname` |
| New `/etc/hosts` resolving `spd` (127.0.0.1 / ::1 / 127.0.1.1) | `components/echo-core/airootfs/etc/hosts` (new) |
| MOTD banner **"SPD Core | Echo OS"** | `components/echo-core/live/etc/motd` |
| `os-release` gains `VARIANT="SPD Core"`, `VARIANT_ID=spd` — `NAME`/`PRETTY_NAME` stay Echo OS | `components/echo-core/airootfs/usr/share/echoos/os-release` |
| Installed-system default hostname **`spd`** (was `${first}-${product}`); Calamares writes `/etc/hostname` + `/etc/hosts` | `components/mad-install/calamares/modules/users.conf` |
| Component display name → **SPD Core** (directory/manifest id `echo-core` kept for assemble/overlay compatibility; documented) | `components/echo-core/README.md` |
| Cross-component "Echo Core" display references → "SPD Core (echo-core)" | `components/echo-boot/README.md`, `components/mad-install/README.md`, `components/echo-install/README.md`, `components/mad-install/ARCHITECTURE.md`, `build/README.md` |
| Validation output: new SPD Core identity block (hostname, hosts, motd banner, os-release VARIANT, installer template) | `build/validate.sh` |

Terminal result: prompt `[archiso@spd ~]$` on the live medium (bash default
`PS1='[\u@\h \W]\$ '` + hostname `spd`; username is always the logged-in
user — nothing is hardcoded). Root gets `[root@spd ~]#` from the same
template. Bash is the only configured shell (live user and installer
`users.conf` both use `/bin/bash`); zsh is present via the archiso package
set but is not the default — no prompt changes were needed there and no
shells were added. `/etc/issue` continues to render `PRETTY_NAME` on TTY
logins (verified on console).

## 2. Universal boot compatibility (PART 2)

### 2a. Live ISO — one hybrid ISO, two independent paths

`build/template/profiledef.sh`:

```bash
if [ "$(uname -m)" = "x86_64" ]; then
    bootmodes=('bios.syslinux' 'uefi.systemd-boot')
else
    bootmodes=('uefi.systemd-boot')
fi
```

- **BIOS path (new):** mkarchiso's `bios.syslinux` mode produces the El
  Torito BIOS boot catalog entry (`/boot/syslinux/isolinux.bin`) **and**
  isohdpfx MBR boot code (`-isohybrid-mbr`, USB BIOS boots work on the same
  image). It depends on no EFI executable. `syslinux` added to
  `components/echo-boot/packages/packages.x86_64` (x86-only; aarch64 stays
  UEFI-only — syslinux does not exist there).
- **UEFI path (preserved, not modified):** `uefi.systemd-boot` staging + the
  build.sh post-patch that installs rEFInd (`refind.conf`, `echoos.conf`,
  fonts, icons, the `themes/wolfe/` theme) into both the ISO 9660 EFI tree
  and `efiboot.img`. The other agent's rEFInd theme work is intact.
- `components/echo-boot/config/syslinux/` (already Echo-branded from the
  v3 era: "Echo OS install medium (x86_64, BIOS)", accessibility, memtest,
  HDT entries) is overlaid into the profile via a new
  `build/config/overlays.tsv` row. The Arch-branded `splash.png` was
  replaced with an Echo-branded one (Echo mark + "Echo OS / SPD Core",
  generated from `echo-mark-light.svg`).
- `build/validate.sh`: syslinux paths removed from the "removed legacy
  payloads" set, bootmode contract flipped to *require* `bios.syslinux` +
  `uefi.systemd-boot` (gated to x86_64), assembled-profile payload checks
  extended. Full validator: **PASSED**.

### 2b. Installed systems (MAD Installer) — already firmware-aware, verified

`shellprocess-refindboot.conf` → `/usr/local/sbin/mad-refindconf-write`
(unchanged, audited):

- detects firmware via `/sys/firmware/efi` (in the chrooted target);
- **UEFI install:** `refind-install --alldrivers --yes`, publishes the
  removable-media fallback `EFI/BOOT/BOOTX64.EFI`, writes
  `refind_linux.conf` + a deterministic manual `refind.conf` on the ESP
  (ESP mounted at `/boot` by `partition.conf`);
- **BIOS install:** `grub-install --target=i386-pc --boot-directory=/boot
  --recheck <disk>` (MBR of the target disk) + `grub-mkconfig`; the `grub`
  package ships via echo-boot. Hook mode refreshes `grub.cfg` on kernel
  updates. `grub` is not installed alongside rEFInd: each firmware branch
  installs exactly one loader.

## 3. Test results (all on `echoos-fox-2026.11.04-x86_64.iso`)

### ISO structural validation (xorriso / file)
- El Torito **BIOS** entry: `-b /boot/syslinux/isolinux.bin -no-emul-boot
  -boot-load-size 4 -boot-info-table` ✔
- El Torito **EFI** entry: `-e …appended_partition_2… -no-emul-boot` ✔
- `-isohybrid-mbr` present; `file` reports `ISO 9660 … (DOS/MBR boot
  sector) … (bootable)` → BIOS USB boots supported ✔
- `/boot/syslinux/isolinux.bin`, `/arch/boot/x86_64/vmlinuz-linux`,
  `/arch/version` present; volume id `ECHO_FOX_202611` ✔

### Boot matrix (actual boots, not configuration-only)

| Path | Firmware | Result |
| --- | --- | --- |
| QEMU SeaBIOS | Legacy BIOS | **PASS** — Echo-branded syslinux menu → kernel+initramfs loaded → same live desktop → `/etc/hostname`=`spd`, MOTD "SPD Core \| Echo OS", `VARIANT="SPD Core"`, `/etc/hosts` resolves spd, `FIRMWARE=bios` |
| QEMU OVMF | UEFI x86_64 | **PASS** — rEFInd menu → kernel+initramfs → same live desktop → `FIRMWARE=uefi`, `efibootmgr` sane, hostname `spd` (no UEFI regression) |
| VMware Workstation | Legacy BIOS | **PASS** — syslinux menu (screenshot: "Echo OS install medium (x86_64, BIOS)") → desktop; `/proc/cmdline` = `…archisosearchuuid=…` (syslinux path), `FIRMWARE=bios` |
| VMware Workstation | UEFI | **PASS** (bonus, run while correcting the VM firmware setting) — rEFInd → desktop → `FIRMWARE=uefi` |

Note: Test-BIOS2's `.vmx` is rewritten from the running VM's in-memory
config at power-off — firmware edits must be made while the VM is powered
off (this caused one false BIOS result that was caught by `/proc/cmdline`
and redone properly).

Both paths reach the **same** live desktop (MAD Installer autostart, Echo
wallpaper, Ash panel) and the same SPD identity.

## 4. Modified / created files

Created:
- `components/echo-core/airootfs/etc/hosts`
- `components/echo-boot/config/syslinux/splash.png` (replaced Arch artwork; rest of `config/syslinux/` was already tracked and Echo-branded)
- `docs/spd-core-hybrid-boot-report.md` (this file)

Modified:
- `components/echo-core/airootfs/etc/hostname` (`spd`)
- `components/echo-core/live/etc/motd` (SPD Core banner)
- `components/echo-core/airootfs/usr/share/echoos/os-release` (VARIANT)
- `components/echo-core/README.md` (SPD Core identity section)
- `components/echo-boot/README.md` (boot modes / BIOS path docs)
- `components/echo-boot/packages/packages.x86_64` (`syslinux`)
- `components/mad-install/calamares/modules/users.conf` (hostname template `spd`)
- `components/mad-install/README.md`, `components/mad-install/ARCHITECTURE.md`, `components/echo-install/README.md`, `build/README.md` (display names)
- `build/config/overlays.tsv` (`echo-boot config/syslinux → syslinux`)
- `build/template/profiledef.sh` (bootmodes)
- `build/validate.sh` (boot contract, parity set, SPD identity checks)
- `out/echoos-fox-2026.11.04-x86_64.iso` (new build)

Not modified: rEFInd implementation (loader binaries, `refind.conf` entries,
theme), Ash Desktop, Echo Boot initramfs config, installer bootloader script
(`mad-refindconf-write`), os-release distribution identity, upstream
package names/licenses.

## 5. Known limitations

1. **32-bit x86**: out of scope — the ISO is x86_64-only; 32-bit-only
   machines need a separate i686/ia32 strategy. Not claimed as supported.
2. **Secure Boot**: UEFI boot is unsigned (rEFInd); Secure Boot must be
   disabled. Signing the chain remains a separate task.
3. **BIOS + GPT installs**: the installer's automatic partitioning uses an
   MBR (msdos) table on BIOS firmware (verified flow of
   `mad-refindconf-write`). Manual GPT-on-BIOS layouts need a `bios_grub`
   (EF02) partition — grub-install refuses without one; the Calamares UI
   does not auto-create it for manual BIOS/GPT layouts.
4. **Real-hardware BIOS USB boot** is covered structurally (isohdpfx MBR)
   but no legacy laptop was available in this session — test on the target
   hardware before claiming hardware support.
5. aarch64 builds remain UEFI-only (no syslinux); not built here (no ARM
   host).

## 6. Rollback instructions

Pre-change backups are in
`/home/ghost/EchoOS-Build/backups/2026-11-04-pre-spdc-bios/`. Full rollback:

```sh
cp backups/2026-11-04-pre-spdc-bios/build/profiledef.sh  build/template/
cp backups/2026-11-04-pre-spdc-bios/build/validate.sh    build/
cp backups/2026-11-04-pre-spdc-bios/build/overlays.tsv   build/config/
# remove the syslinux overlay row from build/config/overlays.tsv
git checkout -- components/echo-core components/mad-install/calamares/modules/users.conf \
                components/echo-boot/packages/packages.x86_64 components/echo-boot/README.md
# optionally: git checkout -- components/echo-boot/config/syslinux/splash.png
sudo rm -rf work && ./build.sh   # work/ must be clean or markers skip payload
```

Per-part rollback:
- Branding only: restore `hostname`, `motd`, `os-release`, `users.conf`,
  READMEs from backups (git-tracked).
- BIOS path only: restore `profiledef.sh`, drop the
  `echo-boot config/syslinux syslinux` overlay row, remove `syslinux` from
  `packages.x86_64`, and re-add the `syslinux/*` entries to the `removed`
  set in `build/validate.sh`. The UEFI/rEFInd path is untouched by BIOS
  changes either way.
