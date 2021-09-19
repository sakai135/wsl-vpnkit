#! /bin/sh

# run from repo root
# ./distro/test.sh

USERPROFILE="$(/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe -c '$env:USERPROFILE' | tr -d '\r')"
DUMP=wsl-vpnkit.tar.gz
TAG_NAME=wslvpnkit

docker build -t $TAG_NAME -f ./distro/Dockerfile .
CONTAINER_ID=$(docker create $TAG_NAME)
docker export $CONTAINER_ID | gzip > $DUMP
docker container rm $CONTAINER_ID
ls -la $DUMP

wsl.exe --unregister wsl-vpnkit
rm -rf $USERPROFILE/wsl-vpnkit
wsl.exe --import wsl-vpnkit "$USERPROFILE\\wsl-vpnkit" $DUMP
rm $DUMP
wsl.exe -d wsl-vpnkit
