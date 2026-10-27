#!/bin/sh
# Echo OS live Plasma session environment.
#
# Keep the live session usable on virtualised GPUs (VMware/VBox/QEMU)
# without forcing software rendering on real hardware: only pin the Qt
# platform to Wayland when the session really is a Wayland session.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    export QT_QPA_PLATFORM="wayland;xcb"
fi
export XDG_CURRENT_DESKTOP="KDE"
export KDE_SESSION_VERSION=6
