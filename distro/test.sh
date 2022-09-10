#! /bin/sh -e

# run from repo root
# ./distro/test.sh

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
wsl.exe --import wsl-vpnkit "$USERPROFILE\\wsl-vpnkit" $DUMP --version 2
rm $DUMP

# tests
(
  # start service
  set -x
  wsl.exe -d wsl-vpnkit service wsl-vpnkit start
  output=$(wsl.exe -d wsl-vpnkit DEBUG=1 service wsl-vpnkit status)
  echo "$output" | grep "Service wsl-vpnkit is running"

  # check latest log
  sleep 5
  output=$(wsl.exe -d wsl-vpnkit sh -c "tac /var/log/wsl-vpnkit.log | awk '{print}; /starting wsl-vpnkit/{exit}' | tac")

  # check for working ping
  echo "$output" | grep "ping success"

  # check for working dns
  echo "$output" | grep "nslookup success"

  # stop service
  wsl.exe -d wsl-vpnkit DEBUG=1 service wsl-vpnkit stop
  output=$(wsl.exe -d wsl-vpnkit DEBUG=1 service wsl-vpnkit status)||true
  echo "$output" | grep "Service wsl-vpnkit is not running"

  # check welcome screen
  wsl.exe -d wsl-vpnkit sh -c 'echo 1 | source /etc/profile'
)

echo "$0 Finished"