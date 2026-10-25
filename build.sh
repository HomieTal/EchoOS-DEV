#!/usr/bin/env bash
# Build the Echo OS ISO using the project's archiso profile.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${SCRIPT_DIR}/profile"
OUT="${SCRIPT_DIR}/out"

# Render pacman.conf from the template so the local [echo] repo path
# is always absolute and correct for this checkout.
"${SCRIPT_DIR}/scripts/render-pacman-conf.sh"

# mkarchiso does not process profile/EFI/BOOT (rEFInd was wired in by
# replacing the systemd-boot binary in the pacstrap dir), so the rEFInd
# config must be kept in sync manually. If an ISO staging tree already
# exists, refresh its refind.conf from the profile so fixes propagate.
if [ -f "${PROFILE}/EFI/BOOT/refind.conf" ] && [ -d "${SCRIPT_DIR}/work/iso/EFI/BOOT" ]; then
    sudo install -m 644 "${PROFILE}/EFI/BOOT/refind.conf" "${SCRIPT_DIR}/work/iso/EFI/BOOT/refind.conf"
fi

mkdir -p "${OUT}"
echo "Profile: ${PROFILE}"
echo "Output:  ${OUT}"
echo "Command: mkarchiso -v -w \"${SCRIPT_DIR}/work\" -o \"${OUT}\" -C \"${PROFILE}/pacman.conf\" \"${PROFILE}\""
echo

sudo mkarchiso -v -w "${SCRIPT_DIR}/work" -o "${OUT}" -C "${PROFILE}/pacman.conf" "${PROFILE}"
