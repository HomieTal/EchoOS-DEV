# Security Policy

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report security issues privately to the repository owner:

- **GitHub:** Open a [private security advisory](https://github.com/HomieTal/EchoOS-DEV/security/advisories/new) (preferred)
- **Contact:** Message [@HomieTal](https://github.com/HomieTal) directly via GitHub

Please include:

1. A clear description of the vulnerability
2. The component or file(s) affected (e.g., Calamares module, `airootfs/` path, build script)
3. Steps to reproduce or a proof-of-concept
4. The potential impact (privilege escalation, data exposure, installer compromise, etc.)
5. Your suggested fix, if any

We aim to acknowledge reports within **72 hours** and provide a resolution timeline within **7 days**.

---

## Supported Versions

Echo OS is currently in **pre-release / active development**. There are no stable release versions yet.

| Version | Supported |
|---|---|
| `main` (development) | ✅ Yes |
| Built ISOs (pre-release) | ⚠️ Best-effort only |
| GitHub archived `main` (pre-2026-10-21) | ❌ No |

Security fixes will be applied to the `main` branch only. No backport branches exist at this stage.

---

## Scope

The following are **in scope** for security reports:

| Area | Examples |
|---|---|
| **Installer (Calamares)** | Privilege escalation via polkit rule, live-to-target file boundary bypass, post-install credential leakage |
| **Live session policy** | Passwordless sudo rules that survive to the installed system, SSH policy leakage |
| **Build scripts** | `build/assemble.sh`, `build/validate.sh`, `scripts/render-pacman-conf.sh` injecting or executing unexpected code |
| **Local `[echo]` package repository** | Tampered or unsigned package substitution |
| **Calamares PKGBUILD** | Supply-chain issues in the Calamares 3.4.2 source or its CMake build |
| **Live/target file boundary** | Files that should be excluded from the installed target (`unpackfs/exclude-list.txt`) but are not |
| **Installed system defaults** | Insecure defaults surviving to the installed target (e.g., live password hashes, live polkit rules) |

---

## Out of Scope

| Area | Reason |
|---|---|
| Vulnerabilities in upstream Arch Linux packages | Report to [Arch Linux Security](https://security.archlinux.org/) |
| Vulnerabilities in Calamares itself | Report to [Calamares upstream](https://github.com/calamares/calamares/security) |
| Live-session security properties | The live environment is intentionally permissive (see below) |
| Physical access attacks on booted live media | Out of threat model for a live distro |
| Issues only reproducible on builds with modified package lists | Out of scope unless the build system itself is the cause |

---

## Known Live-Session Security Design Decisions

The following behaviors are **intentional** in the live environment and are **not vulnerabilities**:

| Behavior | Justification |
|---|---|
| `archiso` user has passwordless `sudo` via `/etc/sudoers.d/archiso` | Standard ArchISO live-session design; this file is excluded from the installed target via `unpackfs/exclude-list.txt` |
| LightDM autologin as `archiso` (UID 1000) | Live-session convenience; the `archiso` user is removed by `calamares removeuser` during installation |
| Calamares is launchable without a password via polkit rule (`50-calamares.rules`) | Live-session installer launch policy; this rule is excluded from the installed target |
| SSH accepts root login with a password in the live session | Live rescue access; the `sshd_config.d/10-archiso.conf` drop-in is excluded from the installed target |
| `faillock` is disabled in the live session (`/etc/security/faillock.conf`) | Prevents live-user lockout; this file is excluded from the installed target |
| Local `[echo]` pacman repo uses `SigLevel = Optional TrustAll` | Build-time local repo only; the repo is not distributed with the ISO or accessible on installed systems. Package signing is a planned hardening task. |

> [!IMPORTANT]
> If you can demonstrate that **any** of the above live-only policies survive to an installed system (i.e., are not correctly excluded by Calamares), that **is** a valid security report. The live/target file boundary is the most critical security property of this installer.

---

## Known Open Issues

The following security-relevant issues are **already documented** and tracked internally. Reporting them again is not necessary:

| ID | Issue |
|---|---|
| F-12 | Several live-only files (e.g., `/etc/calamares/`, `/etc/sysusers.d/99-live-user.conf`, live helper scripts) are not yet excluded from the installed target |
| F-14 | The live password hash appears in both `etc/shadow` and `root/customize_airootfs.sh`; the script is not currently excluded from the installed target |
| F-28 | The local `[echo]` repository uses `SigLevel = Optional TrustAll`; package signing is planned but not implemented |
| F-29 | Five stale entries in `unpackfs/exclude-list.txt` reference paths that do not exist in the profile, making the live/target boundary less auditable |

These will be addressed during active development. If you have additional information about exploitability, please report privately.

---

## Build Security Notes

- **The `packages/` directory is a local-only pacman repository.** Its contents (`calamares-*.pkg.tar.zst`) are gitignored and must be built from the included `PKGBUILD`. A fresh clone does not include pre-built binaries.
- **`profile/pacman.conf` is generated** from `profile/pacman.conf.in` at build time and contains a machine-specific absolute path. It is not a distribution artifact.
- **The assembled profile in `build/generated/`** is a build output and gitignored. It is not a source of truth.
- The `GITHUB_POLICY.md` in this repository governs all changes to the GitHub-hosted copy of this project.
