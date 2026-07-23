#!/bin/sh

VERSION=$(cat /app/version)
ARCH=$(cat /app/arch)

cat <<EOF


wsl-vpnkit ${VERSION} ${ARCH}

wsl-vpnkit is now installed as a WSL 2 distro.
You can close this terminal window.


EOF
