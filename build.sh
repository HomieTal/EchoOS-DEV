#!/usr/bin/env bash
# Build the Echo OS ISO from the deterministic assembled profile.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED="${SCRIPT_DIR}/build/generated/profile"
PROFILE="${GENERATED}"
OUT="${SCRIPT_DIR}/out"

# Assembly is the single source of truth: component overlays, merged package
# lists, profiledef.sh, bootstrap_packages, and a rendered pacman.conf.
"${SCRIPT_DIR}/build/assemble.sh" --arch x86_64 --out "$GENERATED"

# mkarchiso does not process profile/EFI/BOOT (rEFInd was wired in by
# replacing the systemd-boot binary in the pacstrap dir), so the rEFInd
# config must be kept in sync manually. If an ISO staging tree already
# exists, refresh its refind.conf from the assembled profile so fixes
# propagate.
if [ -f "${PROFILE}/EFI/BOOT/refind.conf" ] && [ -d "${SCRIPT_DIR}/work/iso/EFI/BOOT" ]; then
    sudo install -m 644 "${PROFILE}/EFI/BOOT/refind.conf" "${SCRIPT_DIR}/work/iso/EFI/BOOT/refind.conf"
fi

mkdir -p "${OUT}"
echo "Profile: ${PROFILE}"
echo "Output:  ${OUT}"
echo "Command: mkarchiso -v -w \"${SCRIPT_DIR}/work\" -o \"${OUT}\" -C \"${PROFILE}/pacman.conf\" \"${PROFILE}\""
echo

sudo mkarchiso -v -w "${SCRIPT_DIR}/work" -o "${OUT}" -C "${PROFILE}/pacman.conf" "${PROFILE}"
