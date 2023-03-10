#!/bin/bash -xe

# run from repo root
# ./import.sh

CMDSHELL="$(command -v cmd.exe || echo '/mnt/c/Windows/system32/cmd.exe')"
USERPROFILE="$($CMDSHELL /d /v:off /c 'echo | set /p t=%USERPROFILE%' 2>/dev/null)"
DUMP=wsl-vpnkit.tar.gz

# build if necessary
[ -f ${DUMP} ] || ./build.sh

# reinstall
wsl.exe --unregister wsl-vpnkit || :
wsl.exe --import wsl-vpnkit --version 2 "${USERPROFILE}\\wsl-vpnkit" ${DUMP}
