#!/usr/bin/env bash
# Build the Echo OS ISO from the assembled component profile.
#
# Pipeline:
#   1. build/assemble.sh merges the component trees into
#      build/generated/profile (the profile is generated, never edited).
#   2. mkarchiso builds the ISO from that profile into work/out.
#   3. scripts/refind-iso.sh replaces mkarchiso's systemd-boot ESP payload
#      with the Boot component's rEFInd payload and repacks the ISO.
#
# The finished ISO is written to out/ and never overwrites an existing file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${SCRIPT_DIR}/build/generated/profile"
WORK="${SCRIPT_DIR}/work"
OUT="${SCRIPT_DIR}/out"
ARCH="${ARCH:-x86_64}"

echo "Profile: ${PROFILE} (assembled)"
echo "Work:    ${WORK}"
echo "Output:  ${OUT}"

# 1. Assemble the component profile.
"${SCRIPT_DIR}/build/assemble.sh" --arch "${ARCH}" --out "${PROFILE}"

# 2. Build with mkarchiso into a staging output directory so the final ISO
#    can be repacked with rEFInd without clobbering anything.
sudo rm -rf "${WORK}"
sudo mkdir -p "${WORK}/out"
sudo mkarchiso -v -w "${WORK}" -o "${WORK}/out" "${PROFILE}"

MKISO="$(find "${WORK}/out" -maxdepth 1 -name '*.iso' -print -quit)"
if [ -z "${MKISO}" ]; then
    echo "build: mkarchiso did not produce an ISO" >&2
    exit 1
fi

# 2b. Verify the executable bits survived mkarchiso.  The permissions loop in
#     mkarchiso only works when profiledef.sh assigns file_permissions in the
#     global scope (declare -gA); checking the assembled files is not enough.
SFS="$(find "${WORK}/iso" -maxdepth 4 -name airootfs.sfs -print -quit)"
if [ -z "${SFS}" ]; then
    echo "build: mkarchiso did not produce airootfs.sfs" >&2
    exit 1
fi
for script in usr/local/bin/echoos-install-launcher \
              usr/local/bin/echoos-calamares \
              usr/local/bin/choose-mirror \
              usr/local/bin/livecd-sound; do
    mode="$(unsquashfs -ll "${SFS}" "${script}" 2>/dev/null \
        | awk -v path="squashfs-root/${script}" '$NF == path {print $1; exit}')"
    case "${mode}" in
        *x*) ;;
        *)
            echo "build: ${script} has mode '${mode:-missing}' in ${SFS}" >&2
            echo "build: profiledef.sh file_permissions were not applied" >&2
            exit 1
            ;;
    esac
done
echo "build: live script executable modes verified in airootfs.sfs"

# 3. Replace the ESP payload with rEFInd and write the final ISO.
mkdir -p "${OUT}"
sudo "${SCRIPT_DIR}/scripts/refind-iso.sh" "${MKISO}" "${WORK}/iso" "${PROFILE}" "${OUT}"

echo
echo "ISO written to ${OUT}:"
ls -lh "${OUT}"/*.iso
