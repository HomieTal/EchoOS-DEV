#!/usr/bin/env bash
# Render profile/pacman.conf from profile/pacman.conf.in by substituting
# @LOCAL_REPO_PATH@ with the absolute path to the packages/ directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IN="${REPO_ROOT}/profile/pacman.conf.in"
OUT="${REPO_ROOT}/profile/pacman.conf"
REPO_PATH="${REPO_ROOT}/packages"

if [[ ! -f "${IN}" ]]; then
    echo "ERROR: missing ${IN}" >&2
    exit 1
fi

sed "s|@LOCAL_REPO_PATH@|${REPO_PATH}|g" "${IN}" > "${OUT}"
echo "Wrote ${OUT} (repo path: ${REPO_PATH})"
