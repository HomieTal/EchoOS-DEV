#!/usr/bin/env bash
# SPDX-FileCopyrightText: no
# SPDX-License-Identifier: CC0-1.0
#
# Live session fixups, applied after all packages have been installed.
#
# Why this script is needed
# -------------------------
# Installing the packages runs systemd-sysusers inside the chroot (pacman
# hook 30-systemd-sysusers.hook).  That rewrites /etc/passwd, /etc/shadow
# and /etc/group and drops the "archiso" entry from /etc/shadow, so the
# live account ended up without any shadow entry at all.  Consequences in
# the live session:
#
#   * every PAM authentication attempt failed with
#     "unix_chkpwd: check pass; user unknown",
#   * pam_faillock therefore locked the live account out after three
#     tries, which is the "N minutes left to unlock" screen.
#
# mkarchiso runs this script after the packages are installed, so the
# state written here is final for the live image.
#
# Note: the live account is removed from the installed system by the
# Calamares "removeuser" module, so none of this reaches the target.

set -euo pipefail

LIVE_USER="archiso"
LIVE_UID="1000"
LIVE_GID="1000"
LIVE_HOME="/home/archiso"
LIVE_SHELL="/bin/bash"
LIVE_GECOS="Live user"

# SHA-512 hash of the live user's password ("archiso").
LIVE_PASSWD='$6$echooslive$3CTNE3UTs.g04ztg.2woIVqWsMDUAgG.TO9aNRD1fhGAud84r2zaBrvEXbINMqeOvPOY3OKZqkg4oa.jxavd5.'

# Groups the live session needs: "autologin" is what
# /etc/pam.d/lightdm-autologin checks, the rest are the usual desktop
# memberships (screen, audio, removable media, ...).
LIVE_GROUPS=(autologin wheel audio video storage network lp)

# --- account -------------------------------------------------------------
if ! getent passwd "${LIVE_USER}" >/dev/null; then
    useradd --no-create-home \
            --uid "${LIVE_UID}" \
            --gid "${LIVE_GID}" \
            --shell "${LIVE_SHELL}" \
            --comment "${LIVE_GECOS}" \
            "${LIVE_USER}"
fi

# --- groups --------------------------------------------------------------
for group in "${LIVE_GROUPS[@]}"; do
    getent group "${group}" >/dev/null || groupadd --system "${group}"
    usermod --append --groups "${group}" "${LIVE_USER}"
done

# --- shadow entry --------------------------------------------------------
# This is the part that actually matters: without a shadow entry PAM
# reports "user unknown" and rejects every password.
usermod --password "${LIVE_PASSWD}" "${LIVE_USER}"

# --- home directory ------------------------------------------------------
if [[ -d "${LIVE_HOME}" ]]; then
    chown "${LIVE_UID}:${LIVE_GID}" "${LIVE_HOME}"
    chmod 0750 "${LIVE_HOME}"
fi

# --- report --------------------------------------------------------------
echo "customize_airootfs: live user '${LIVE_USER}' ready"
getent passwd "${LIVE_USER}"
getent shadow "${LIVE_USER}" | cut -d: -f1,2 | sed 's/:.*/:<hash>/'
id "${LIVE_USER}"
