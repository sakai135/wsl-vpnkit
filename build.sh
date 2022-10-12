#! /bin/sh -xe

# run from repo root
# ./build.sh

USERPROFILE="$(powershell.exe -c 'Write-Host -NoNewline $env:USERPROFILE')"
DUMP=wsl-vpnkit.tar.gz
TAG_NAME=wslvpnkit

# build
docker build -t $TAG_NAME -f ./distro/Dockerfile .
CONTAINER_ID=$(docker create $TAG_NAME)
docker export $CONTAINER_ID | gzip > $DUMP
docker container rm $CONTAINER_ID
ls -la $DUMP

# reinstall
wsl.exe --unregister wsl-vpnkit || :
wsl.exe --import wsl-vpnkit "C:\Program Files\wsl-vpnkit" $DUMP --version 2
rm $DUMP
