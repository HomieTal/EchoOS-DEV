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
# support files must be kept in sync manually: after mkarchiso, install
# refind.conf / echoos.conf / fonts / icons into BOTH the ISO 9660
# EFI/BOOT tree and the EFI system partition image (efiboot.img) — rEFInd
# reads its configuration from the FAT partition it was launched from.
mkdir -p "${OUT}"
echo "Profile: ${PROFILE}"
echo "Output:  ${OUT}"
echo "Command: mkarchiso -v -w \"${SCRIPT_DIR}/work\" -o \"${OUT}\" -C \"${PROFILE}/pacman.conf\" \"${PROFILE}\""
echo

run_mkarchiso() {
    sudo mkarchiso -v -w "${SCRIPT_DIR}/work" -o "${OUT}" -C "${PROFILE}/pacman.conf" "${PROFILE}"
}

run_mkarchiso

# --- post-mkarchiso rEFInd patch -------------------------------------------
ESP_IMG="${SCRIPT_DIR}/work/efiboot.img"
if [ -f "${PROFILE}/EFI/BOOT/BOOTx64.EFI" ] && [ -d "${SCRIPT_DIR}/work/iso/EFI/BOOT" ]; then
    for f in refind.conf echoos.conf; do
        [ -f "${PROFILE}/EFI/BOOT/${f}" ] && sudo install -m 644 \
            "${PROFILE}/EFI/BOOT/${f}" "${SCRIPT_DIR}/work/iso/EFI/BOOT/${f}"
    done
    for d in fonts icons; do
        if [ -d "${PROFILE}/EFI/BOOT/${d}" ]; then
            sudo mkdir -p "${SCRIPT_DIR}/work/iso/EFI/BOOT/${d}"
            sudo cp -r "${PROFILE}/EFI/BOOT/${d}" "${SCRIPT_DIR}/work/iso/EFI/BOOT/"
        fi
    done
fi
if [ -f "${ESP_IMG}" ] && [ -f "${PROFILE}/EFI/BOOT/refind.conf" ]; then
    sudo mkdir -p /tmp/echoos-esp
    if sudo mount -o loop "${ESP_IMG}" /tmp/echoos-esp 2>/dev/null; then
        for f in refind.conf echoos.conf; do
            [ -f "${PROFILE}/EFI/BOOT/${f}" ] && sudo install -m 644 \
                "${PROFILE}/EFI/BOOT/${f}" "/tmp/echoos-esp/EFI/BOOT/${f}"
        done
        for d in fonts icons; do
            if [ -d "${PROFILE}/EFI/BOOT/${d}" ]; then
                sudo mkdir -p "/tmp/echoos-esp/EFI/BOOT/${d}"
                sudo cp -r "${PROFILE}/EFI/BOOT/${d}" "/tmp/echoos-esp/EFI/BOOT/"
            fi
        done
        sudo umount /tmp/echoos-esp
        echo "rEFInd support files installed into efiboot.img"
    else
        echo "WARNING: could not mount ${ESP_IMG} for the rEFInd patch" >&2
    fi
fi

# Rebuild only the xorriso stage so the patched ESP lands in the ISO.
if [ -f "${SCRIPT_DIR}/work/build._build_buildmode_iso" ]; then
    sudo rm -f "${SCRIPT_DIR}/work/build._build_buildmode_iso"
    run_mkarchiso
fi
