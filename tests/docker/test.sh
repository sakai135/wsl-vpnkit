#!/bin/sh

set -eu

script=/app/wsl-vpnkit
log_dir=/run/wsl-vpnkit-test
mkdir -p "$log_dir"

fail () {
    echo "FAIL: $1" >&2
    exit 1
}

print_log () {
    [ "${DEBUG:-}" = 1 ] || return 0
    cat "$1"
}

start_background () {
    log_file=$1
    shift
    "$@" >"$log_file" 2>&1 &
    pid=$!
}

stop_background () {
    kill -TERM "$pid"
    wait "$pid" 2>/dev/null || :
    print_log "$1"
}

assert_clean () {
    tap_name=${1:-wsltap}
    if ip link show dev "$tap_name" >/dev/null 2>&1; then
        fail "$tap_name still exists"
    fi
    if [ "$(iptables -t nat -S)" != "$original_nat" ]; then
        fail "iptables rules were not restored"
    fi
}

original_route=$(ip -4 route show default)
original_gateway=$(printf '%s\n' "$original_route" | awk 'NR == 1 { print $3 }')
original_nat=$(iptables -t nat -S)
[ -n "$original_route" ] || fail "container has no default route"

common_env="WSL_INTEROP=1 WSL2_GATEWAY_IP=$original_gateway WSL2_TAP_NAME=eth0"
common_env="$common_env WSL2_RESOLVCONF=/etc/resolv.conf"
common_env="$common_env VMEXEC_PATH=/tests/mock-vm"
common_env="$common_env MOCK_LOG_DIR=$log_dir"

echo "case: default startup and SIGTERM cleanup"
rm -f "$log_dir/vm.log"
# shellcheck disable=SC2086
start_background "$log_dir/default.log" env WSL_INTEROP=1 "$script"
sleep 2
ip link show dev wsltap >/dev/null 2>&1 || fail "default startup did not create tap"
stop_background "$log_dir/default.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "default route was not restored"
assert_clean

echo "case: startup and SIGTERM cleanup"
# shellcheck disable=SC2086
start_background "$log_dir/static.log" env $common_env CHECK_HOST=127.0.0.1 \
    CHECK_DNS=127.0.0.1 MOCK_VM_MODE=run "$script"
sleep 2
ip link show dev wsltap >/dev/null 2>&1 || fail "static startup did not create tap"
grep -q -- "ssh-port=-1" "$log_dir/vm.log" ||
    fail "startup did not pass default ssh-port"
grep -q -- "-preexisting=1" "$log_dir/vm.log" ||
    fail "startup did not pass preexisting"
grep -q -- "-iface=wsltap" "$log_dir/vm.log" ||
    fail "startup did not pass tap name"
grep -q -- "-stop-if-exist=" "$log_dir/vm.log" ||
    fail "startup did not request stale VM cleanup"
stop_background "$log_dir/static.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "route was not restored"
assert_clean

echo "case: configurable tap name and SSH port"
rm -f "$log_dir/vm.log"
# shellcheck disable=SC2086
start_background "$log_dir/custom.log" env $common_env TAP_NAME=customtap \
    GVPROXY_SSH_PORT=2222 \
    CHECK_HOST=127.0.0.1 CHECK_DNS=127.0.0.1 MOCK_VM_MODE=run \
    "$script"
sleep 2
ip link show dev customtap >/dev/null 2>&1 || fail "custom tap was not created"
grep -q -- "ssh-port=2222" "$log_dir/vm.log" ||
    fail "custom SSH port was not passed"
grep -q -- "-iface=customtap" "$log_dir/vm.log" ||
    fail "custom tap name was not passed"
stop_background "$log_dir/custom.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "custom route was not restored"
assert_clean customtap

echo "case: configurable tap network values"
# shellcheck disable=SC2086
start_background "$log_dir/network.log" env $common_env TAP_NAME=networktap \
    VPNKIT_GATEWAY_IP=192.168.126.1 VPNKIT_HOST_IP=192.168.126.254 \
    VPNKIT_LOCAL_IP=192.168.126.2 TAP_MAC_ADDR=5a:94:ef:e4:0c:ef \
    CHECK_HOST=127.0.0.1 CHECK_DNS=127.0.0.1 MOCK_VM_MODE=run "$script"
sleep 2
ip -4 addr show dev networktap | grep -q -- "192.168.126.2/24" ||
    fail "custom local IP was not applied"
ip route show default | grep -q -- "default via 192.168.126.1 dev networktap" ||
    fail "custom gateway was not applied"
ip link show dev networktap | grep -q -- "5a:94:ef:e4:0c:ef" ||
    fail "custom tap MAC was not applied"
stop_background "$log_dir/network.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "network route was not restored"
assert_clean networktap

echo "case: config static DHCP lease configures the preexisting tap"
config_file="$log_dir/wsl-vpnkit config & ? test.yaml"
cat >"$config_file" <<'EOF'
stack:
  subnet: 192.168.127.0/24
  gatewayIP: 192.168.127.1
  gatewayVirtualIPs:
  - 192.168.127.254
  dhcpStaticLeases:
    192.168.127.2: 5a:94:ef:e4:0c:ef
EOF
config_query=$(printf '%s' "$config_file" | jq -sRr @uri)
# shellcheck disable=SC2086
start_background "$log_dir/config.log" env $common_env \
    GVPROXY_CONFIG="$config_file" CHECK_HOST=127.0.0.1 CHECK_DNS=127.0.0.1 \
    MOCK_VM_MODE=run "$script"
sleep 2
ip -4 addr show dev wsltap | grep -q -- "192.168.127.2/24" ||
    fail "config static lease address was not applied"
ip link show dev wsltap | grep -q -- "5a:94:ef:e4:0c:ef" ||
    fail "config static lease MAC was not applied"
grep -q -- "config=$config_query" "$log_dir/vm.log" ||
    fail "config file was not passed to wsl-vm with URL-safe escaping"
stop_background "$log_dir/config.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "config route was not restored"
assert_clean

echo "case: wsl-vm-owned DHCP lease"
# shellcheck disable=SC2086
start_background "$log_dir/dhcp.log" env $common_env PREEXISTING=0 \
    DHCP_TIMEOUT=5 CHECK_HOST=127.0.0.1 CHECK_DNS=127.0.0.1 \
    MOCK_DHCP_MODE=success MOCK_VM_MODE=run "$script"
sleep 2
ip -4 addr show dev wsltap | grep -q -- "192.168.127.2/24" ||
    fail "DHCP lease was not applied"
ip -4 route show default | grep -q -- "default via 192.168.127.1 dev wsltap" ||
    fail "DHCP TAP route was not made the default route"
stop_background "$log_dir/dhcp.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "DHCP route was not restored"
assert_clean

echo "case: DHCP timeout cleans up"
if env $common_env PREEXISTING=0 DHCP_TIMEOUT=2 DHCP_POLL_INTERVAL=1 \
    MOCK_DHCP_MODE=timeout MOCK_VM_MODE=run "$script" \
    >"$log_dir/dhcp-timeout.log" 2>&1; then
    fail "DHCP timeout was reported as success"
fi
grep -q -- "DHCP did not assign" "$log_dir/dhcp-timeout.log" ||
    fail "DHCP timeout error was not shown"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "DHCP timeout route was not restored"
assert_clean

echo "case: modified resolv.conf warning"
modified_resolvconf="$log_dir/modified-resolv.conf"
printf 'nameserver %s\n' "$original_gateway" >"$modified_resolvconf"
# shellcheck disable=SC2086
start_background "$log_dir/resolvconf.log" env $common_env \
    WSL2_RESOLVCONF="$modified_resolvconf" CHECK_HOST=127.0.0.1 \
    CHECK_DNS=127.0.0.1 MOCK_VM_MODE=run "$script"
sleep 2
grep -q -- "resolv.conf has been modified without setting generateResolvConf" \
    "$log_dir/resolvconf.log" || fail "resolv.conf warning was not shown"
stop_background "$log_dir/resolvconf.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "resolv.conf route was not restored"
assert_clean
rm -f "$modified_resolvconf"

echo "case: VM exit cleans up"
# shellcheck disable=SC2086
if env $common_env CHECK_HOST=127.0.0.1 CHECK_DNS=127.0.0.1 MOCK_VM_MODE=exit \
    "$script" >"$log_dir/failure.log" 2>&1; then
    fail "VM exit was reported as success"
fi
print_log "$log_dir/failure.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "failure route was not restored"
assert_clean

echo "case: missing VM executable fails before setup"
if env $common_env VMEXEC_PATH=/does-not-exist "$script" >"$log_dir/missing-vm.log" 2>&1; then
    fail "missing VM executable was accepted"
fi
grep -q -- "VMEXEC_PATH \[/does-not-exist\] does not exist" "$log_dir/missing-vm.log" ||
    fail "missing VM executable error was not shown"

echo "case: missing gvproxy executable fails before setup"
if env $common_env GVPROXY_PATH=/does-not-exist "$script" >"$log_dir/missing-gvproxy.log" 2>&1; then
    fail "missing gvproxy executable was accepted"
fi
grep -q -- "GVPROXY_PATH \[/does-not-exist\] does not exist" \
    "$log_dir/missing-gvproxy.log" || fail "missing gvproxy executable error was not shown"

echo "case: executable paths with spaces are accepted"
space_dir="$log_dir/space dir"
mkdir -p "$space_dir"
cp /tests/mock-vm "$space_dir/mock vm"
cp /usr/local/bin/wsl-gvproxy.exe "$space_dir/gvproxy exe"
# shellcheck disable=SC2086
start_background "$log_dir/space-paths.log" env \
    WSL_INTEROP=1 WSL2_GATEWAY_IP=$original_gateway WSL2_TAP_NAME=eth0 \
    WSL2_RESOLVCONF=/etc/resolv.conf \
    VMEXEC_PATH="$space_dir/mock vm" \
    GVPROXY_PATH="$space_dir/gvproxy exe" \
    MOCK_LOG_DIR=$log_dir \
    CHECK_HOST=127.0.0.1 CHECK_DNS=127.0.0.1 MOCK_VM_MODE=run \
    "$script"
sleep 2
ip link show dev wsltap >/dev/null 2>&1 || fail "startup with executable paths containing spaces did not create tap"
grep -q -- "%20" "$log_dir/vm.log" || fail "gvproxy path with spaces was not URL-encoded"
stop_background "$log_dir/space-paths.log"
[ "$(ip -4 route show default)" = "$original_route" ] || fail "route was not restored after path-with-spaces startup"
assert_clean

echo "PASS: wsl-vpnkit Docker harness"
