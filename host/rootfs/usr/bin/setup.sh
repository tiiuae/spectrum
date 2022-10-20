#!/bin/sh
# SPDX-FileCopyrightText: 2022 Unikie>

export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=/run/user/0
export WESTON_CONFIG_FILE=/etc/xdg/weston/weston.ini

echo "12345678901264758695847364857456" > /etc/machine-id
mkdir -p /home/apprunner
mkdir /tmp && chmod 0777 /tmp
adduser apprunner -D -h /home/apprunner
chown apprunner:apprunner /home/apprunner
chown -R apprunner:apprunner /run/user/0
chown apprunner /dev/pts/0
chmod -R 0755 /run/user/0
chmod 666 /dev/null
chmod 666 /dev/urandom
chmod 666 /dev/tty
chmod 666 /dev/dri/card0
chmod 666 /dev/dri/renderD128

# element-desktop  --enable-features=UseOzonePlatform --ozone-platform=wayland

# /nix/store/npknxl8a5lnc451pj3c2sqbpl5qdri5a-electron-19.0.7/bin/electron --enable-features=UseOzonePlatform --ozone-platform=wayland

# chromium --enable-features=UseOzonePlatform --ozone-platform=wayland