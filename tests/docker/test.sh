#!/bin/sh

set -eu

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

find_process_pid () {
    export process_pattern=$1
    process_pid=$(ps -eo pid=,args= |
        awk 'index($0, ENVIRON["process_pattern"]) { print $1; exit }')
    unset process_pattern
    [ -n "$process_pid" ] || return 1
    printf '%s\n' "$process_pid"
}

assert_process_stopped () {
    process_pid=$1
    process_name=$2
    attempts=0
    while [ "$attempts" -lt 50 ]; do
        process_state=$(ps -o stat= -p "$process_pid" 2>/dev/null | tr -d ' ')
        [ -z "$process_state" ] && return 0
        case "$process_state" in
            Z*) return 0 ;;
        esac
        sleep 0.1
        attempts=$((attempts + 1))
    done
    fail "$process_name did not stop"
}

assert_tcp_port_listening () {
    port=$1
    attempts=0
    while [ "$attempts" -lt 50 ]; do
        if ss -H -ltn "sport = :$port" | grep -q .; then
            return 0
        fi
        sleep 0.1
        attempts=$((attempts + 1))
    done
    fail "TCP port $port is not listening"
}

assert_tcp_port_unused () {
    port=$1
    if ss -H -ltn "sport = :$port" | grep -q .; then
        fail "TCP port $port is listening"
    fi
}

wait_for () {
    message=$1
    shift
    attempts=0
    while [ "$attempts" -lt 50 ]; do
        if "$@"; then
            return 0
        fi
        sleep 0.1
        attempts=$((attempts + 1))
    done
    fail "$message"
}

interface_exists () {
    ip link show dev "$1" >/dev/null 2>&1
}

process_exists () {
    find_process_pid "$1" >/dev/null 2>&1
}

log_contains () {
    grep -q -- "$2" "$1" 2>/dev/null
}

address_present () {
    ip -4 addr show dev "$1" | grep -q -- "$2"
}

route_present () {
    ip -4 route show default | grep -q -- "$1"
}

assert_clean () {
    tap_name=${1:-wsltap}
    [ "$(ip -4 route show default)" = "$original_route" ] ||
        fail "route was not restored"
    if ip link show dev "$tap_name" >/dev/null 2>&1; then
        fail "$tap_name still exists"
    fi
    if [ "$(iptables -t nat -S)" != "$original_nat" ]; then
        fail "iptables rules were not restored"
    fi
}

assert_nat_active () {
    gateway=$1
    host_ip=$2
    tap_name=$3
    vpn_gateway=$4
    nat_rules=$(iptables -t nat -S)
    for rule in \
        "-A PREROUTING -d ${gateway}/32 -p udp -m udp --dport 53 -j DNAT --to-destination ${vpn_gateway}:53" \
        "-A PREROUTING -d ${gateway}/32 -p tcp -m tcp --dport 53 -j DNAT --to-destination ${vpn_gateway}:53" \
        "-A PREROUTING -d ${gateway}/32 -j DNAT --to-destination ${host_ip}" \
        "-A OUTPUT -d ${gateway}/32 -p udp -m udp --dport 53 -j DNAT --to-destination ${vpn_gateway}:53" \
        "-A OUTPUT -d ${gateway}/32 -p tcp -m tcp --dport 53 -j DNAT --to-destination ${vpn_gateway}:53" \
        "-A OUTPUT -d ${gateway}/32 -j DNAT --to-destination ${host_ip}" \
        "-A POSTROUTING -o ${tap_name} -j MASQUERADE"; do
        printf '%s\n' "$nat_rules" | grep -F -- "$rule" >/dev/null ||
            fail "missing active NAT rule: $rule"
    done
}

original_route=$(ip -4 route show default)
original_gateway=$(printf '%s\n' "$original_route" | awk 'NR == 1 { print $3 }')
original_nat=$(iptables -t nat -S)
[ -n "$original_route" ] || fail "container has no default route"

common_env="WSL_INTEROP=1 WSL2_GATEWAY_IP=$original_gateway WSL2_TAP_NAME=eth0"
common_env="$common_env WSL2_RESOLVCONF=/etc/resolv.conf"
mock_env="$common_env VMEXEC_PATH=/tests/mock-vm MOCK_LOG_DIR=$log_dir"

echo "case: default startup and SIGTERM cleanup"
rm -f "$log_dir/vm.log"
# shellcheck disable=SC2086
start_background "$log_dir/default.log" env WSL_INTEROP=1 wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
wait_for "wsl-vm did not start" process_exists wsl-vm
wait_for "wsl-gvproxy.exe did not start" process_exists wsl-gvproxy.exe
wait_for "diagnostics did not pass" log_contains "$log_dir/default.log" \
    "check: all diagnostic checks passed"
ps -eo args= | grep -E -- '[w]sl-vm' >/dev/null || fail "wsl-vm did not start"
ps -eo args= | grep -E -- '[w]sl-gvproxy.exe' >/dev/null || fail "wsl-gvproxy.exe did not start"
vm_pid=$(find_process_pid 'wsl-vm') ||
    fail "could not find wsl-vm process"
gvproxy_pid=$(find_process_pid 'wsl-gvproxy.exe') ||
    fail "could not find wsl-gvproxy.exe process"
ip link show dev wsltap >/dev/null 2>&1 || fail "default startup did not create tap"
ip -4 addr show dev wsltap | grep -q -- "192.168.127.2/24" ||
    fail "default startup did not configure the local IP"
ip -4 route show default | grep -q -- "default via 192.168.127.1 dev wsltap" ||
    fail "default startup did not configure the VPN gateway route"
assert_nat_active "$original_gateway" 192.168.127.254 wsltap 192.168.127.1
grep -q -- "check: all diagnostic checks passed" "$log_dir/default.log" ||
    fail "default startup diagnostics did not pass"
assert_tcp_port_unused 2222
stop_background "$log_dir/default.log"
assert_process_stopped "$vm_pid" wsl-vm
assert_process_stopped "$gvproxy_pid" wsl-gvproxy.exe
assert_clean

echo "case: real wsl-vm-owned DHCP lease with real gvproxy"
# Exercise the VM-owned TAP path with the actual gvisor-tap-vsock binaries.
# shellcheck disable=SC2086
start_background "$log_dir/real-dhcp.log" env $common_env \
    PREEXISTING=0 TAP_NAME=realdhcptap DHCP_TIMEOUT=10 \
    wsl-vpnkit
wait_for "realdhcptap was not created" interface_exists realdhcptap
wait_for "wsl-vm did not start" process_exists wsl-vm
wait_for "wsl-gvproxy.exe did not start" process_exists wsl-gvproxy.exe
wait_for "realdhcptap did not receive an address" log_contains "$log_dir/real-dhcp.log" \
    "check: ✔️ local address configured for realdhcptap"
ip -4 addr show dev realdhcptap | grep -q -- "192.168.127.2/24" ||
    fail "real wsl-vm did not configure the DHCP local IP"
ip -4 route show default |
    grep -q -- "default via 192.168.127.1 dev realdhcptap" ||
    fail "real wsl-vm did not configure the DHCP default route"
assert_nat_active "$original_gateway" 192.168.127.254 realdhcptap 192.168.127.1
grep -q -- "check: ✔️ local address configured for realdhcptap" "$log_dir/real-dhcp.log" ||
    fail "real DHCP local address diagnostic did not pass"
real_vm_pid=$(find_process_pid 'wsl-vm') ||
    fail "could not find real wsl-vm process"
real_gvproxy_pid=$(find_process_pid 'wsl-gvproxy.exe') ||
    fail "could not find real wsl-gvproxy.exe process"
stop_background "$log_dir/real-dhcp.log"
assert_process_stopped "$real_vm_pid" wsl-vm
assert_process_stopped "$real_gvproxy_pid" wsl-gvproxy.exe
assert_clean realdhcptap

echo "case: diagnostic failures do not stop the VPN"
diagnostic_failure_path="$log_dir/diagnostic-failure-bin"
mkdir -p "$diagnostic_failure_path"
printf '%s\n' '#!/bin/sh' 'exit 1' >"$diagnostic_failure_path/nslookup"
chmod 755 "$diagnostic_failure_path/nslookup"
# Force DNS checks to fail to exercise their advisory behavior.
# shellcheck disable=SC2086
start_background "$log_dir/diagnostic-failure.log" env $mock_env \
    PATH="$diagnostic_failure_path:$PATH" wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
wait_for "diagnostic failure was not reported" log_contains \
    "$log_dir/diagnostic-failure.log" "diagnostic check(s) failed"
find_process_pid '/tests/mock-vm' >/dev/null ||
    fail "diagnostic failure stopped wsl-vm"
grep -q -- "diagnostic check(s) failed" "$log_dir/diagnostic-failure.log" ||
    fail "diagnostic failure was not reported"
stop_background "$log_dir/diagnostic-failure.log"
assert_clean

echo "case: configurable tap name"
rm -f "$log_dir/vm.log"
# shellcheck disable=SC2086
start_background "$log_dir/custom.log" env $mock_env TAP_NAME=customtap GVPROXY_SSH_PORT=2222 wsl-vpnkit
wait_for "customtap was not created" interface_exists customtap
wait_for "custom tap was not passed" log_contains "$log_dir/vm.log" "-iface=customtap"
grep -q -- "-iface=customtap" "$log_dir/vm.log" ||
    fail "custom tap name was not passed"
grep -q -- "-preexisting=1" "$log_dir/vm.log" ||
    fail "startup did not pass preexisting"
grep -q -- "-stop-if-exist=" "$log_dir/vm.log" ||
    fail "startup did not request stale VM cleanup"
stop_background "$log_dir/custom.log"
assert_clean customtap

echo "case: SSH port forwarding"
# shellcheck disable=SC2086
start_background "$log_dir/ssh-port.log" env $common_env \
    GVPROXY_SSH_PORT=2222 wsl-vpnkit
assert_tcp_port_listening 2222
stop_background "$log_dir/ssh-port.log"
assert_clean

echo "case: configurable tap network values"
# shellcheck disable=SC2086
start_background "$log_dir/network.log" env $common_env TAP_NAME=networktap \
    VPNKIT_GATEWAY_IP=192.168.126.1 VPNKIT_HOST_IP=192.168.126.254 \
    VPNKIT_LOCAL_IP=192.168.126.2 TAP_MAC_ADDR=5a:94:ef:e4:0c:ef \
    wsl-vpnkit
wait_for "networktap was not created" interface_exists networktap
wait_for "networktap did not receive an address" address_present networktap \
    "192.168.126.2/24"
wait_for "custom gateway was not applied" route_present \
    "default via 192.168.126.1 dev networktap"
ip link show dev networktap | grep -q -- "5a:94:ef:e4:0c:ef" ||
    fail "custom tap MAC was not applied"
stop_background "$log_dir/network.log"
assert_clean networktap

echo "case: config static DHCP lease configures the preexisting tap"
config_file="$log_dir/wsl-vpnkit config & ? test.yaml"
cat >"$config_file" <<'EOF'
stack:
  subnet: 192.168.126.0/24
  gatewayIP: 192.168.126.1
  gatewayVirtualIPs:
  - 192.168.126.254
  dhcpStaticLeases:
    192.168.126.2: 5a:94:ef:e4:0c:ef
EOF
config_query=$(printf '%s' "$config_file" | jq -sRr @uri)
# shellcheck disable=SC2086
start_background "$log_dir/config.log" env $mock_env GVPROXY_CONFIG="$config_file" wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
wait_for "wsltap did not receive an address" address_present wsltap "192.168.126.2/24"
ip link show dev wsltap | grep -q -- "5a:94:ef:e4:0c:ef" ||
    fail "config static lease MAC was not applied"
grep -q -- "config=$config_query" "$log_dir/vm.log" ||
    fail "config file was not passed to wsl-vm with URL-safe escaping"
stop_background "$log_dir/config.log"
assert_clean

echo "case: config DHCP lease with a VM-owned tap"
rm -f "$log_dir/vm.log"
# shellcheck disable=SC2086
start_background "$log_dir/config-dhcp.log" env $mock_env \
    GVPROXY_CONFIG="$config_file" PREEXISTING=0 \
    MOCK_DHCP_IP=192.168.126.2 MOCK_DHCP_GATEWAY=192.168.126.1 \
    wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
wait_for "wsltap did not receive an address" address_present wsltap "192.168.126.2/24"
wait_for "configured DHCP route was not applied" route_present \
    "default via 192.168.126.1 dev wsltap"
ip link show dev wsltap | grep -q -- "5a:94:ef:e4:0c:ef" ||
    fail "configured DHCP MAC was not applied"
grep -q -- "-mac=5a:94:ef:e4:0c:ef" "$log_dir/vm.log" ||
    fail "configured DHCP MAC was not passed to wsl-vm"
stop_background "$log_dir/config-dhcp.log"
assert_clean

echo "case: wsl-vm-owned DHCP lease"
# shellcheck disable=SC2086
start_background "$log_dir/dhcp.log" env $mock_env PREEXISTING=0 VPNKIT_SUBNET_MASK=16 DHCP_TIMEOUT=5 \
    MOCK_DHCP_IP=192.168.127.2 MOCK_DHCP_GATEWAY=192.168.127.1 wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
wait_for "wsltap did not receive an address" address_present wsltap "192.168.127.2/24"
wait_for "diagnostics did not pass" log_contains "$log_dir/dhcp.log" \
    "check: ✔️ local address configured for wsltap"
wait_for "DHCP TAP route was not made the default route" route_present \
    "default via 192.168.127.1 dev wsltap"
grep -q -- "check: ✔️ local address configured for wsltap" "$log_dir/dhcp.log" ||
    fail "DHCP local address diagnostic did not pass"
stop_background "$log_dir/dhcp.log"
assert_clean

echo "case: DHCP timeout cleans up"
if env $mock_env PREEXISTING=0 DHCP_TIMEOUT=2 DHCP_POLL_INTERVAL=1 \
    MOCK_VM_MODE=run wsl-vpnkit \
    >"$log_dir/dhcp-timeout.log" 2>&1; then
    fail "DHCP timeout was reported as success"
fi
grep -q -- "DHCP did not assign" "$log_dir/dhcp-timeout.log" ||
    fail "DHCP timeout error was not shown"
assert_clean

echo "case: invalid configuration fails before setup"
assert_config_failure () {
    name=$1
    expected=$2
    shift 2
    invalid_config="$log_dir/invalid-$name.yaml"
    printf '%s\n' "$@" >"$invalid_config"
    if env $mock_env GVPROXY_CONFIG="$invalid_config" wsl-vpnkit \
        >"$log_dir/invalid-$name.log" 2>&1; then
        fail "$name configuration was accepted"
    fi
    grep -F -q -- "$expected" "$log_dir/invalid-$name.log" ||
        fail "$name configuration error was not shown"
    assert_clean
}
assert_config_failure empty "is empty" ""
assert_config_failure missing-host "missing stack.gatewayVirtualIPs[0]" \
    "stack:" "  gatewayIP: 192.168.127.1" "  subnet: 192.168.127.0/24"
assert_config_failure missing-gateway "missing stack.gatewayIP" \
    "stack:" "  gatewayVirtualIPs:" "  - 192.168.127.254" \
    "  subnet: 192.168.127.0/24"
assert_config_failure invalid-subnet "invalid stack.subnet" \
    "stack:" "  gatewayVirtualIPs:" "  - 192.168.127.254" \
    "  gatewayIP: 192.168.127.1" "  subnet: 192.168.127.0/33"
if env $mock_env GVPROXY_CONFIG="$log_dir/does-not-exist.yaml" \
    wsl-vpnkit >"$log_dir/missing-config.log" 2>&1; then
    fail "missing GVPROXY_CONFIG was accepted"
fi
grep -q -- "GVPROXY_CONFIG .* does not exist" "$log_dir/missing-config.log" ||
    fail "missing GVPROXY_CONFIG error was not shown"
assert_clean

echo "case: modified resolv.conf warning"
modified_resolvconf="$log_dir/modified-resolv.conf"
printf 'nameserver %s\n' "$original_gateway" >"$modified_resolvconf"
# shellcheck disable=SC2086
start_background "$log_dir/resolvconf.log" env $common_env \
    WSL2_RESOLVCONF="$modified_resolvconf" \
    wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
grep -q -- "resolv.conf has been modified without setting generateResolvConf" \
    "$log_dir/resolvconf.log" || fail "resolv.conf warning was not shown"
stop_background "$log_dir/resolvconf.log"
assert_clean
rm -f "$modified_resolvconf"

echo "case: VM exit cleans up"
# shellcheck disable=SC2086
if env $mock_env MOCK_VM_MODE=exit \
    wsl-vpnkit >"$log_dir/failure.log" 2>&1; then
    fail "VM exit was reported as success"
fi
print_log "$log_dir/failure.log"
assert_clean

echo "case: missing VM executable fails before setup"
if env $common_env VMEXEC_PATH=/does-not-exist wsl-vpnkit >"$log_dir/missing-vm.log" 2>&1; then
    fail "missing VM executable was accepted"
fi
grep -q -- "VMEXEC_PATH \[/does-not-exist\] does not exist" "$log_dir/missing-vm.log" ||
    fail "missing VM executable error was not shown"

echo "case: non-executable VM path fails before setup"
non_executable_vm="$log_dir/non-executable-vm"
: >"$non_executable_vm"
chmod 644 "$non_executable_vm"
if env $common_env VMEXEC_PATH="$non_executable_vm" wsl-vpnkit \
    >"$log_dir/non-executable-vm.log" 2>&1; then
    fail "non-executable VM path was accepted"
fi
grep -q -- "VMEXEC_PATH \[$non_executable_vm\] is not executable" \
    "$log_dir/non-executable-vm.log" ||
    fail "non-executable VM path error was not shown"
assert_clean

echo "case: missing gvproxy executable fails before setup"
if env $common_env GVPROXY_PATH=/does-not-exist wsl-vpnkit >"$log_dir/missing-gvproxy.log" 2>&1; then
    fail "missing gvproxy executable was accepted"
fi
grep -q -- "GVPROXY_PATH \[/does-not-exist\] does not exist" \
    "$log_dir/missing-gvproxy.log" || fail "missing gvproxy executable error was not shown"

echo "case: non-executable gvproxy path fails before setup"
non_executable_gvproxy="$log_dir/non-executable-gvproxy"
: >"$non_executable_gvproxy"
chmod 644 "$non_executable_gvproxy"
if env $common_env GVPROXY_PATH="$non_executable_gvproxy" wsl-vpnkit \
    >"$log_dir/non-executable-gvproxy.log" 2>&1; then
    fail "non-executable gvproxy path was accepted"
fi
grep -q -- "is not executable due to WSL interop" "$log_dir/non-executable-gvproxy.log" ||
    fail "non-executable gvproxy error was not shown"
assert_clean

echo "case: invalid environment fails before setup"
if env $mock_env WSL_INTEROP=1 PREEXISTING=2 wsl-vpnkit \
    >"$log_dir/invalid-preexisting.log" 2>&1; then
    fail "invalid PREEXISTING was accepted"
fi
grep -q -- "PREEXISTING must be 0 or 1" "$log_dir/invalid-preexisting.log" ||
    fail "invalid PREEXISTING error was not shown"
assert_clean
if env $mock_env WSL_INTEROP= wsl-vpnkit >"$log_dir/missing-interop.log" 2>&1; then
    fail "missing WSL_INTEROP was accepted"
fi
grep -q -- "WSL interop not available" "$log_dir/missing-interop.log" ||
    fail "missing WSL_INTEROP error was not shown"
assert_clean

echo "case: failing gvproxy is rejected after execution attempt"
failing_gvproxy="$log_dir/failing-gvproxy"
printf '%s\n' '#!/bin/sh' 'exit 1' >"$failing_gvproxy"
chmod 755 "$failing_gvproxy"
if env $common_env VMEXEC_PATH=/usr/local/bin/wsl-vm \
    GVPROXY_PATH="$failing_gvproxy" wsl-vpnkit >"$log_dir/failing-gvproxy.log" 2>&1; then
    fail "failing gvproxy was accepted"
fi
grep -q -- "is not executable due to WSL interop" "$log_dir/failing-gvproxy.log" ||
    fail "failing gvproxy error was not shown"
assert_clean

echo "case: default route auto-detection"
# shellcheck disable=SC2086
start_background "$log_dir/autodetect.log" env $mock_env \
    WSL_INTEROP=1 WSL2_GATEWAY_IP= WSL2_TAP_NAME= WSL2_RESOLVCONF= \
    wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
grep -q -- "WSL2_TAP_NAME=eth0" "$log_dir/autodetect.log" ||
    fail "default route tap auto-detection failed"
grep -q -- "WSL2_GATEWAY_IP=$original_gateway" "$log_dir/autodetect.log" ||
    fail "default route gateway auto-detection failed"
stop_background "$log_dir/autodetect.log"
assert_clean

echo "case: resolv.conf gateway auto-detection"
resolvconf_autodetect="$log_dir/autodetect-resolv.conf"
printf 'nameserver %s\n' "$original_gateway" >"$resolvconf_autodetect"
real_ip=$(command -v ip)
autodetect_path="$log_dir/autodetect-bin"
mkdir -p "$autodetect_path"
cat >"$autodetect_path/ip" <<EOF
#!/bin/sh
if [ "\$1" = "-j" ] && [ "\$2" = "route" ] && [ "\$3" = "show" ] && [ "\$4" = "default" ]; then
    printf '%s\n' '[]'
    exit 0
fi
exec "$real_ip" "\$@"
EOF
chmod 755 "$autodetect_path/ip"
# shellcheck disable=SC2086
start_background "$log_dir/autodetect-resolv.log" env $mock_env \
    PATH="$autodetect_path:$PATH" WSL_INTEROP=1 WSL2_GATEWAY_IP= \
    WSL2_TAP_NAME= WSL2_RESOLVCONF="$resolvconf_autodetect" \
    wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
grep -q -- "WSL2_GATEWAY_IP=$original_gateway" "$log_dir/autodetect-resolv.log" ||
    fail "resolv.conf gateway auto-detection failed"
stop_background "$log_dir/autodetect-resolv.log"
assert_clean

echo "case: executable paths with spaces are accepted"
space_dir="$log_dir/space dir"
mkdir -p "$space_dir"
cp /usr/local/bin/wsl-vm "$space_dir/temp vm"
cp /usr/local/bin/wsl-gvproxy.exe "$space_dir/temp gvproxy"
# shellcheck disable=SC2086
start_background "$log_dir/space-paths.log" env \
    WSL_INTEROP=1 WSL2_GATEWAY_IP=$original_gateway WSL2_TAP_NAME=eth0 \
    WSL2_RESOLVCONF=/etc/resolv.conf \
    VMEXEC_PATH="$space_dir/temp vm" \
    GVPROXY_PATH="$space_dir/temp gvproxy" \
    wsl-vpnkit
wait_for "wsltap was not created" interface_exists wsltap
wait_for "temp vm did not start" process_exists "temp vm"
wait_for "temp gvproxy did not start" process_exists "temp gvproxy"
space_vm_pid=$(find_process_pid 'temp vm') ||
    fail "could not find wsl-vm process with a space-containing path"
space_gvproxy_pid=$(find_process_pid 'temp gvproxy') ||
    fail "could not find wsl-gvproxy.exe process with a space-containing path"
stop_background "$log_dir/space-paths.log"
assert_process_stopped "$space_vm_pid" wsl-vm
assert_process_stopped "$space_gvproxy_pid" wsl-gvproxy.exe
assert_clean

echo "PASS: wsl-vpnkit Docker harness"
