#!/bin/sh

VERSION=$(cat /app/version)
ARCH=$(cat /app/arch)

cat <<EOF


wsl-vpnkit ${VERSION} ${ARCH}

wsl-vpnkit is now installed as a WSL 2 distro.
Use the following command from your normal WSL 2 distro to start.

wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit


EOF
