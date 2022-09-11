#! /bin/sh -xe

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
for debug_value in '1' ''; do
  if [ -n "${debug_value}" ]; then
    debug_str="DEBUG=${debug_value}"
  else
    debug_str=""
  fi
  echo "####### Test Round with debug_str [${debug_str}] #######"

  # start service
  wsl.exe -d wsl-vpnkit ${debug_str} service wsl-vpnkit start
  output=$(wsl.exe -d wsl-vpnkit ${debug_str} service wsl-vpnkit status)
  echo "$output" | grep --colour=always "Service wsl-vpnkit is running"

  # check latest log
  sleep 5
  output=$(wsl.exe -d wsl-vpnkit sh -c "tac /var/log/wsl-vpnkit.log | awk '{print}; /starting wsl-vpnkit/{exit}' | tac")

  ( set +x  # avoid clutter during output checks
    # check for working ping
    echo "$output" | grep --colour=always "ping success"

    # check for working dns
    echo "$output" | grep --colour=always "nslookup success"
  )

  # restart service
  wsl.exe -d wsl-vpnkit ${debug_str} service wsl-vpnkit restart
  output=$(wsl.exe -d wsl-vpnkit ${debug_str} service wsl-vpnkit status)
  echo "$output" | grep --colour=always "Service wsl-vpnkit is running"

  # stop service
  wsl.exe -d wsl-vpnkit ${debug_str} service wsl-vpnkit stop
  output=$(wsl.exe -d wsl-vpnkit ${debug_str} service wsl-vpnkit status)||echo "ignoring exit code"
  echo "$output" | grep --colour=always "Service wsl-vpnkit is not running"

  # check welcome screen
  wsl.exe -d wsl-vpnkit sh -c 'echo 1 | source /etc/profile'
done

echo "$0 Finished"