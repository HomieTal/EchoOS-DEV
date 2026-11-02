# MAD Installer — Environment Report

Date: 2026-10-31 · Host: Arch Linux (kernel 7.2.11-arch1-1, x86_64)

## Host

| Item | Value |
| --- | --- |
| OS | Arch Linux (rolling), kernel 7.2.11-arch1-1 |
| Architecture | x86_64 |
| RAM | 15 GiB (11 GiB in use during tests — heavy desktop session) |
| Storage | /tmp has ~3 GiB free on tmpfs (7.7G, 61% used); VM disks kept in /tmp/mad-vm |
| KVM | `/dev/kvm` present, acceleration used (`-machine accel=kvm`) |
| QEMU | qemu-system-x86_64 (system package), qemu-img available |
| libvirt / virt-manager | not used (plain QEMU with QMP automation; libvirt not required for this test matrix) |
| OVMF | `/usr/share/edk2/x64/OVMF_CODE.4m.fd` + `OVMF_VARS.4m.fd` (UEFI testing) |
| Other tooling | rsvg-convert / ImageMagick (asset generation), qmllint (QML validation), mkarchiso (ISO builds) |

## Repository state

- Repo: `/home/ghost/EchoOS-Build/EchoOS-DEV` (git, HEAD `bac9292`).
- MAD Installer component: `components/mad-install` (order 40 in
  `build/config/components.tsv`).
- Original Echo Install: `components/echo-install` — untouched (verified).
- Build scripts: `build.sh` → `build/assemble.sh` + `mkarchiso`.
- ISO output: `out/` (echoos-fox-YYYY.MM.DD-x86_64.iso; date pinned by
  `work/build_date`).
- Existing ISOs: audited 2026.10.29 in `releases/2026.10.29/audited/`
  (SHA-256 verified), plus freshly built MAD ISO in `out/`.

## Missing dependencies / environment notes

- **Host OOM risk (important):** with 4 GiB guest RAM while the desktop
  session is busy, the kernel OOM-killed the test VM during an install run
  (kernel log: `Out of memory: Killed process … qemu-system-x86`,
  02:01). Subsequent install tests use **3 GiB guest RAM** and avoid
  concurrent heavy host activity. This is a test-environment constraint,
  not an installer defect.
- libvirt/virt-manager not installed → VM matrix is driven by plain QEMU +
  QMP (`input-send-event`, `screendump`). Functional equivalent for the
  required scenarios; all disks disposable qcow2.
- QEMU build lacks virtio-vga/virtio-vga-gl → standard `VGA` device used.

## Virtualization support check

- `ls -l /dev/kvm` → present, used successfully (ISO boot → live desktop in
  ~60 s).
- UEFI firmware verified via OVMF boot of both ISOs.
- Guest networking: user-mode NAT (slirp) — not required by the installer
  (offline install by design).
