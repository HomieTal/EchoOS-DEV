# MAD Installer — Architecture

## 1. System position

```
Echo Boot          SPD Core             Ash Desktop         MAD Installer
(live boot,        (live root, base     (Plasma/SDDM/       (installer UI,
 rEFInd media)      system)              theme)              install engine)
      └──────────────────┴──────────────────────┴───────────────┬─┘
                                          build/assemble.sh ───┘
                                                  │
                                       build/generated/profile
                                                  │
                                          mkarchiso → ISO
```

MAD Installer is an Echo OS assembly component (`components/mad-install`,
registry row order 40, requires `echo-core,echo-boot,echo-desktop`). It is
merged into the generated profile by `build/assemble.sh` through the overlay
rows in `build/config/overlays.tsv`:

| Source prefix | Destination |
| --- | --- |
| `calamares` | `airootfs/etc/calamares` |
| `config/live` | `airootfs/etc` |
| `config/home` | `airootfs/home` |
| `config/rootfs` | `airootfs` |

## 2. Honest engine statement

**The installation engine is Calamares 3.4.2.** The frontend is rebranded and
redesigned; the runtime, libraries, and modules are not replaced. Nothing in
this repository claims engine independence. The long-term goal (an
independent MAD installation engine) is tracked in `ROADMAP.md`.

Frontend/backend separation is nevertheless real: every user-visible file
(branding, strings, artwork, stylesheet, launcher, desktop integration) lives
inside this component, and every backend behavior (module sequence, module
configs, unpackfs exclusions, bootloader scripts) lives in files that could
be driven by a different frontend without modification.

## 3. Component map

```text
mad-install/
├── calamares/                    BACKEND + FRONTEND CONFIG
│   ├── settings.conf             module sequence, instances, branding: mad
│   ├── modules/*.conf            18 module configurations
│   └── branding/mad/             FRONTEND: identity, artwork, QSS, slideshow
├── config/
│   ├── live/                     live-session-only (polkit, autostart)
│   ├── home/archiso/Desktop/     live desktop shortcut
│   └── rootfs/                   helper scripts + hicolor icon (live + target)
├── packages/                     calamares 3.4.2 recipe + package lists
├── docs/                         design tokens, findings, copy verification
└── packaging/                    independent mad-installer package recipe
```

## 4. Execution flow

### 4.1 Launch (live session)

```
Desktop shortcut / XDG autostart
        │  /usr/share/applications equivalent (config/home, config/live)
        ▼
mad-installer-launcher        single-instance guard, session settle wait,
        │                     xhost grant for root under Xwayland,
        │                     log: /tmp/mad-installer-launcher.log
        ▼ pkexec (stock Calamares polkit action, live rule: 50-mad-installer.rules)
/usr/bin/calamares            runs as root
```

Fallback wrapper `mad-installer-x11` pins `QT_QPA_PLATFORM=xcb`
(unused in the verified launch path; see `docs/PHASE5-FINDINGS.md` F2).

### 4.2 UI sequence (show)

`welcome → locale → keyboard → partition → users → summary → finished`

The MAD presentation layer consists of: `branding/mad/branding.desc`
(strings, window, sidebar colors), `stylesheet.qss` (full widget theme),
`slideshow.qml` (execution-step presentation), and the generated logo assets.
Calamares 3.4.2's widget+QSS surface is the supported customization boundary;
QML panels are not viable on this backend (verified —
`docs/PHASE5-FINDINGS.md`).

### 4.3 Install sequence (exec)

| Stage | Modules | Contract |
| --- | --- | --- |
| Populate | `partition`, `mount`, `unpackfs` | offline copy of the live SquashFS; `packages` module is a no-op |
| Users | `shellprocess@sysusers`, `removeuser`, `users` | repair target user db, drop live user, create real account at uid 1000 |
| Identity | `machineid`, `locale`, `keyboard`, `localecfg`, `fstab`, `initcpiocfg`, `initcpio`, `displaymanager`, `hwclock`, `services-systemd` | SDDM + networkd + resolved enabled |
| Boot | `shellprocess@refindboot` → `mad-refindconf-write --bootstrap` | UEFI: rEFInd → ESP + fallback; BIOS (x86_64): GRUB → MBR |
| Cleanup | `shellprocess@cleanup`, `umount` | exclude live-only state (see 4.4) |

### 4.4 Live/target boundary

`calamares/modules/unpackfs/exclude-list.txt` is the authoritative contract
for what does **not** reach the installed system: live account home, live
autologin/SDDM drop-ins, display-manager link, live sudo/SSH/faillock/polkit
rules, mirror/pacman-init units, and MAD's own launcher/autostart files.

## 5. Module contracts (plug-and-build boundaries)

Each unit below declares responsibility, inputs, outputs, dependencies, and
failure behavior. These are the seams along which future replacement happens.

### M1 — Branding frontend (replaceable today)
- **Responsibility:** identity, artwork, theme, slideshow.
- **Inputs:** `branding.desc`, assets in `calamares/branding/mad/`.
- **Output:** Calamares UI presentation.
- **Dependencies:** Calamares 3.4.2 branding API (verified selectors:
  `docs/DESIGN-TOKENS.md`).
- **Failure:** missing/invalid branding.desc → Calamares refuses to start.
- **Replacement candidate:** any Calamares branding component; later, a
  non-Calamares frontend.

### M2 — Launcher (replaceable today)
- **Responsibility:** single entry point; privilege escalation via pkexec
  only; session readiness; logging.
- **Inputs:** desktop environment state.
- **Output:** Calamares process as root.
- **Failure:** exits non-zero with a log entry; never degrades to sudo.
- **Replacement candidate:** new escalation mechanism per engine.

### M3 — Disk detection / partitioning (`partition`, `mount` configs)
- **Responsibility:** disk selection, erase/alongside/manual layouts, EFI
  detection, mount planning. Uses kpmcore via Calamares.
- **Inputs:** user choices in the UI; block devices.
- **Output:** mounted target at `/` (+ ESP at `/boot` on UEFI).
- **Failure:** Calamares partition module aborts with UI error; nothing is
  written before the explicit final confirmation.
- **Replacement candidate:** a MAD disk engine speaking an Installation API.

### M4 — Payload (`unpackfs` + exclude list)
- **Responsibility:** copy the live SquashFS to the target; strip live-only
  state.
- **Inputs:** source SquashFS, `exclude-list.txt`.
- **Output:** populated target root.
- **Failure:** unpackfs error aborts the install before configuration.
- **Replacement candidate:** image-based deployment (e.g. direct disk image
  writing).

### M5 — User configuration (`users`, `sysusers`, `removeuser`, `displaymanager`)
- **Responsibility:** create uid-1000 account, password, hostname, SDDM
  wiring.
- **Failure:** module error surfaces in the install progress view.
- **Replacement candidate:** part of a MAD system-configuration API.

### M6 — Bootloader integration (`shellprocess@refindboot`, `mad-refindconf-write`, `mad-refind-sync.hook`)
- **Responsibility:** UEFI: rEFInd into ESP, removable fallback, ESP-root
  kernel publication, deterministic manual boot entry, kernel-update resync
  via libalpm hook. BIOS (x86_64 only): GRUB into MBR + `grub.cfg`.
- **Inputs:** target fstab (`root=UUID=`), firmware mode, target disk.
- **Output:** bootable ESP/MBR configuration.
- **Failure:** logged to `/var/log/echoos-bootloader.log` in the target and
  reported by Calamares; install is not marked successful.
- **Replacement candidate:** a MAD boot manager component (see ROADMAP).

### M7 — Post-install (`shellprocess@cleanup`)
- **Responsibility:** final target cleanup.
- **Replacement candidate:** post-install hook pipeline of the future engine.

### M8 — Packaging (`packages/`, `packaging/`)
- **Responsibility:** calamares runtime package + mad-installer integration
  package.
- **Contract:** x86_64 today; aarch64 explicitly unsupported (empty
  `packages.aarch64`, no installer advertised).

## 6. Safety model

- Destructive operations only after explicit user confirmation
  (Calamares partition page + summary "Install now" dialog).
- Escalation exclusively via `pkexec` + stock polkit action.
- No hardcoded disk paths anywhere in MAD scripts (target disk derived from
  mounts at runtime).
- Preview (summary) and execution are separate, distinct screens.
- Real backend progress only; the slideshow carries no fake percentages.
- Failures are logged (`/tmp/mad-installer-launcher.log`,
  `/var/log/echoos-bootloader.log` in the target) and surface in the UI;
  success is never claimed past a failed operation.

## 7. Future engine seam

```
MAD UI  →  Installation API  →  Installation Backend  →  Linux system
(today: Calamares widgets/QSS          (today: Calamares 3.4.2
 + branding)                            modules + kpmcore)
```

The contracts in §5 are the seam. A future backend must implement: disk
query/plan/commit, payload deployment, user/locale/boot configuration, and
progress/error reporting. See `ROADMAP.md`.
