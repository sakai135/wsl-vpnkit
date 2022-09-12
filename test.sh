#! /bin/sh -xe

# ensuring distro is stopped before running tests
if wsl.exe -d wsl-vpnkit service wsl-vpnkit status; then
  wsl.exe -d wsl-vpnkit service wsl-vpnkit stop || \
  wsl.exe -t wsl-vpnkit
fi

# tests
for debug_value in '1' '2' ''; do
  if [ -n "${debug_value}" ]; then
    debug_str="DEBUG=${debug_value}"
  else
    debug_str=""
  fi
  echo "####### Test Round with debug_str [${debug_str}] #######" | grep --colour=always .

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

echo "$0 Finished" | grep --colour=always .