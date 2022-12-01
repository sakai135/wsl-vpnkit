#!/bin/bash -xe

# run from repo root
# ./import.sh

USERPROFILE=$(wslvar USERPROFILE)
DUMP=wsl-vpnkit.tar.gz

# build if necessary
[ -f ${DUMP} ] || ./build.sh

# reinstall
wsl.exe --unregister wsl-vpnkit || :
wsl.exe --import wsl-vpnkit --version 2 "${USERPROFILE}\\wsl-vpnkit" ${DUMP}
