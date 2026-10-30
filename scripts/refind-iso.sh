#!/usr/bin/env bash
# Repack the mkarchiso staging tree into a rEFInd-bootable ISO.
#
# mkarchiso always installs systemd-boot as \EFI\BOOT\BOOTX64.EFI for the
# uefi.systemd-boot boot mode; it has no hook for replacing the ESP payload.
# Echo OS boots rEFInd, so after mkarchiso has produced the ISO staging tree
# (work/iso) this helper:
#
#   1. replaces <stage>/EFI/BOOT with the Boot component's rEFInd payload,
#   2. builds a new FAT ESP image containing rEFInd, the boot menu and the
#      kernel/initramfs (the layout the live ISO has always used),
#   3. repacks the ISO with exactly the xorriso options mkarchiso uses for
#      bios.syslinux + an appended UEFI ESP partition.
#
# The input ISO is only used to validate that mkarchiso ran; the output is
# rebuilt from the staging tree so the result never depends on a previous
# build of the repository.
#
# Usage: scripts/refind-iso.sh <mkarchiso-iso> <stage-dir> <profile-dir> <out-dir>
set -euo pipefail

die() { echo "refind-iso: $*" >&2; exit 1; }

[ $# -eq 4 ] || die "usage: refind-iso.sh <mkarchiso-iso> <stage-dir> <profile-dir> <out-dir>"
INPUT_ISO="$1"
STAGE="$(realpath "$2")"
PROFILE="$(realpath "$3")"
OUTDIR="$4"

[ -f "$INPUT_ISO" ] || die "mkarchiso output not found: $INPUT_ISO"
[ -d "$STAGE" ] || die "ISO staging tree not found: $STAGE"
[ -f "$PROFILE/EFI/BOOT/BOOTx64.EFI" ] || die "rEFInd payload missing: $PROFILE/EFI/BOOT/BOOTx64.EFI"
[ -f "$PROFILE/EFI/BOOT/refind.conf" ] || die "rEFInd config missing: $PROFILE/EFI/BOOT/refind.conf"
[ -f "$STAGE/boot/syslinux/isolinux.bin" ] || die "syslinux staging files missing (bios.syslinux boot mode required)"
[ -f "$STAGE/arch/boot/x86_64/vmlinuz-linux" ] || die "kernel missing from ISO staging tree"
[ -f "$STAGE/arch/boot/x86_64/initramfs-linux.img" ] || die "initramfs missing from ISO staging tree"

# shellcheck disable=SC1090
source "$PROFILE/profiledef.sh"

# mkarchiso gets the architecture on its command line; profiledef.sh only
# defines the ISO metadata.
arch="${ARCH:-x86_64}"

install -d "$OUTDIR"
FINAL_ISO="$OUTDIR/${iso_name}-${iso_version}-${arch}.iso"
[ -e "$FINAL_ISO" ] && die "refusing to overwrite existing ISO: $FINAL_ISO"

# --- 1. rEFInd payload on the ISO 9660 tree --------------------------------
echo "refind-iso: installing rEFInd payload into $STAGE/EFI/BOOT"
rm -rf "$STAGE/EFI/BOOT"
install -d -m 0755 "$STAGE/EFI/BOOT"
cp -a "$PROFILE/EFI/BOOT/." "$STAGE/EFI/BOOT/"

# --- 2. FAT ESP image ------------------------------------------------------
ESP="$OUTDIR/.efiboot-refind.img"
TMP_ISO="$OUTDIR/.${iso_name}-${iso_version}-${arch}.iso.tmp"
rm -f "$ESP" "$TMP_ISO"
trap 'rm -f "$ESP" "$TMP_ISO"' EXIT

esp_files=("$STAGE/EFI" "$STAGE/arch/boot/x86_64")
if compgen -G "$STAGE/shell*.efi" >/dev/null; then
    esp_files+=("$STAGE/shell"*.efi)
fi
imgsize_kib="$(du -bcs -- "${esp_files[@]}" | awk '
    function ceil(x){return int(x)+(x>int(x))}
    function byte_to_kib(x){return x/1024}
    function mib_to_kib(x){return x*1024}
    END {print mib_to_kib(ceil((byte_to_kib($1)+8192)/1024))}')"
echo "refind-iso: creating FAT ESP image (${imgsize_kib} KiB)"
mkfs.fat -C -n ARCHISO_EFI -F 32 "$ESP" "$imgsize_kib" >/dev/null
mmd -i "$ESP" ::/EFI ::/arch ::/arch/boot ::/arch/boot/x86_64
mcopy -s -i "$ESP" "$STAGE/EFI"/* ::/EFI/
mcopy -i "$ESP" \
    "$STAGE/arch/boot/x86_64/vmlinuz-linux" \
    "$STAGE/arch/boot/x86_64/initramfs-linux.img" \
    ::/arch/boot/x86_64/
for ucode in "$STAGE"/arch/boot/*-ucode.img; do
    [ -e "$ucode" ] || continue
    mcopy -i "$ESP" "$ucode" ::/arch/boot/
done
if compgen -G "$STAGE/shell*.efi" >/dev/null; then
    for shell in "$STAGE/shell"*.efi; do
        mcopy -i "$ESP" "$shell" ::/
    done
fi

# --- 3. repack -------------------------------------------------------------
echo "refind-iso: repacking ISO -> $FINAL_ISO"
xorriso -no_rc -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -joliet \
    -joliet-long \
    -rational-rock \
    -volid "${iso_label}" \
    -appid "${iso_application}" \
    -publisher "${iso_publisher}" \
    -preparer "prepared by mkarchiso + refind-iso" \
    -eltorito-boot boot/syslinux/isolinux.bin \
    -eltorito-catalog boot/syslinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr "$STAGE/boot/syslinux/isohdpfx.bin" \
    --mbr-force-bootable \
    -partition_offset 16 \
    -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$ESP" \
    -isohybrid-gpt-basdat \
    -eltorito-alt-boot \
    -e --interval:appended_partition_2:all:: \
    -no-emul-boot \
    -output "$TMP_ISO" \
    "$STAGE/"

mv "$TMP_ISO" "$FINAL_ISO"
echo "refind-iso: wrote $FINAL_ISO"
