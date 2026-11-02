#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="echoos-fox"
iso_label="ECHO_FOX_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Echo OS (Arch Linux based)"
iso_application="Echo OS x86_64 Live/Rescue DVD"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M' '-processors' '4')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
kernel_params_aarch64="clk_ignore_unused pd_ignore_unused arm64.nopauth"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:000"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/echoos-desktop-branding"]="0:0:755"
  ["/etc/passwd"]="0:0:644"
  ["/etc/group"]="0:0:644"
  ["/etc/sudoers.d/archiso"]="0:0:440"
  ["/etc/polkit-1/rules.d/50-calamares.rules"]="0:0:644"
  ["/etc/sysusers.d/99-live-user.conf"]="0:0:644"
  ["/etc/lightdm"]="0:0:755"
  ["/etc/lightdm/lightdm.conf"]="0:0:644"
  ["/etc/lightdm/lightdm-gtk-greeter.conf"]="0:0:644"
  ["/etc/lightdm/lightdm.conf.d"]="0:0:755"
  ["/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"]="0:0:644"
  ["/usr/share/echoos/echo-mark.png"]="0:0:644"
  ["/etc/polkit-1/rules.d"]="0:0:755"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sysusers.d"]="0:0:755"
  ["/home/archiso"]="1000:1000:750"
  ["/home/archiso/Desktop"]="1000:1000:755"
  ["/home/archiso/Desktop/mad-installer.desktop"]="1000:1000:755"
  ["/usr/local/bin/mad-installer-launcher"]="0:0:755"
  ["/usr/local/sbin/mad-refindconf-write"]="0:0:755"
)
