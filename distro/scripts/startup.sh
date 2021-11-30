#! /bin/sh

LOG_PATH="/var/log/wsl-vpnkit.log"
USERPROFILE=$(wslpath "$(powershell.exe -NoLogo -NoProfile -c 'Write-Host -NoNewline $env:USERPROFILE')")
VERSION="$(cat /app/version)"
CONF_PATH="$USERPROFILE/wsl-vpnkit/wsl-vpnkit.conf"

touch $LOG_PATH

mkdir -p "$USERPROFILE/wsl-vpnkit/"
if [ ! -f "$CONF_PATH" ]; then
  cp /app/defaults.conf "$CONF_PATH"
fi

echo "
wsl-vpnkit $VERSION
This distro is only intended for running wsl-vpnkit. 

Run the following commands from Windows or other WSL 2 distros to use.

    wsl.exe -d $WSL_DISTRO_NAME service wsl-vpnkit start
    wsl.exe -d $WSL_DISTRO_NAME service wsl-vpnkit stop

or just create an alias:

    echo 'alias vpnkit="wsl.exe -d wsl-vpnkit service wsl-vpnkit"' >/etc/profile.d/vpnkit.sh
    source /etc/profile.d/vpnkit.sh
    vpnkit start
    vpnkit stop

The following files will be copied if they do not already exist.

    $USERPROFILE/wsl-vpnkit/wsl-vpnkit.exe
    $USERPROFILE/wsl-vpnkit/npiperelay.exe

Logs for wsl-vpnkit can be viewed here.

    wsl.exe -d $WSL_DISTRO_NAME tail -f $LOG_PATH

Config for wsl-vpnkit can be edited here.

    $USERPROFILE/wsl-vpnkit/wsl-vpnkit.conf

Run the following command to see the default values.

    wsl.exe -d $WSL_DISTRO_NAME cat /app/defaults.conf

Press [enter] key to continue...
"
read _
exit 0
