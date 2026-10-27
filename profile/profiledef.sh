#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="echoos-fox"
iso_label="ECHO_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Echo OS <https://homietal.github.io/Echo/>"
iso_application="Echo OS Live/Rescue DVD"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
kernel_params_aarch64="clk_ignore_unused pd_ignore_unused arm64.nopauth"
# mkarchiso sources this file from inside a function.  Use -g so the
# associative array is assigned in mkarchiso's global scope; a plain
# `declare -A` would create a function-local array and the permissions
# loop would silently do nothing.
declare -gA file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:000"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/etc/passwd"]="0:0:644"
  ["/etc/group"]="0:0:644"
  ["/etc/sudoers.d/archiso"]="0:0:440"
  ["/etc/polkit-1/rules.d/50-calamares.rules"]="0:0:644"
  ["/etc/sysusers.d/99-live-user.conf"]="0:0:644"
  ["/etc/sddm.conf"]="0:0:644"
  ["/etc/sddm.conf.d"]="0:0:755"
  ["/etc/sddm.conf.d/10-echoos-live-autologin.conf"]="0:0:644"
  ["/etc/xdg/plasma-workspace/env/20-echoos-session.sh"]="0:0:755"
  ["/usr/local/bin/echoos-calamares"]="0:0:755"
  ["/etc/polkit-1/rules.d"]="0:0:755"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sysusers.d"]="0:0:755"
  ["/home/archiso"]="1000:1000:750"
  ["/home/archiso/Desktop"]="1000:1000:755"
  ["/home/archiso/Desktop/echoos-install.desktop"]="1000:1000:755"
  ["/usr/local/bin/echoos-install-launcher"]="0:0:755"
)
