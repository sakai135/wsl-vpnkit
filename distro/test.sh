#! /bin/sh -e

# run from repo root
# ./distro/test.sh

USERPROFILE="$(powershell.exe -c 'Write-Host -NoNewline $env:USERPROFILE')"
DUMP=wsl-vpnkit.tar.gz
TAG_NAME=wslvpnkit

docker build -t $TAG_NAME -f ./distro/Dockerfile .
CONTAINER_ID=$(docker create $TAG_NAME)
docker export $CONTAINER_ID | gzip > $DUMP
docker container rm $CONTAINER_ID
ls -la $DUMP

wsl.exe --unregister wsl-vpnkit
wsl.exe --import wsl-vpnkit "$USERPROFILE\\wsl-vpnkit" $DUMP
rm $DUMP
wsl.exe -d wsl-vpnkit
