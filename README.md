# wsl-vpnkit

`wsl-vpnkit` provides network connectivity for WSL 2 when your Windows VPN blocks access. It requires no changes to Windows settings or administrator privileges on the Windows host.

For previous versions, see [v0.3](https://github.com/sakai135/wsl-vpnkit/tree/v0.3.x) and [v0.2](https://github.com/sakai135/wsl-vpnkit/tree/v0.2.x).

## Setup

Before setting up `wsl-vpnkit`, try `ping 1.2.3.4` inside WSL 2. If the ping succeeds, follow the steps in [WSL has no network connectivity once connected to a VPN](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#wsl-has-no-network-connectivity-once-connected-to-a-vpn) instead. WSL 2 networking options like [mirrored mode](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking) and other [`.wslconfig` options](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#wslconfig) may resolve the issue as well.

`wsl-vpnkit` is intended for cases where those options do not work.

### Option A: install `wsl-vpnkit` as a distro

Download `wsl-vpnkit-amd64.wsl` (or `wsl-vpnkit-arm64.wsl` for ARM64) from the [latest release](https://github.com/sakai135/wsl-vpnkit/releases/latest) and open it to import the distro into WSL 2. This option lets you start `wsl-vpnkit` even when your existing WSL distro has no network connectivity.

Run the following command to start `wsl-vpnkit` in the foreground.

```sh
wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit
```

#### Setup systemd

You can optionally use systemd to start `wsl-vpnkit` when your WSL 2 distro starts. Create the service file in your existing WSL 2 distro and enable the service.

```sh
# copy the service file from wsl-vpnkit to your distro
wsl.exe -d wsl-vpnkit --cd /app cat /app/wsl-vpnkit.service | sudo tee /etc/systemd/system/wsl-vpnkit.service

sudo systemctl enable wsl-vpnkit
sudo systemctl start wsl-vpnkit
systemctl status wsl-vpnkit
```

#### Update

To update, unregister the existing `wsl-vpnkit` distro and open the new `wsl-vpnkit.wsl` to import the new version.

```sh
wsl.exe --unregister wsl-vpnkit
```

### Option B: install as a standalone script

The `wsl-vpnkit` script can be installed and run in your existing distro. The following is an example setup script for Ubuntu.

```sh
# install dependencies
sudo apt-get install iproute2 iptables iputils-ping dnsutils curl jq yq

# download wsl-vpnkit and unpack
curl -L https://github.com/sakai135/wsl-vpnkit/releases/latest/download/wsl-vpnkit-amd64.wsl -o wsl-vpnkit.wsl
tar --strip-components=1 -xf wsl-vpnkit.wsl app/wsl-vpnkit app/wsl-vpnkit.yaml app/wsl-gvproxy.exe app/wsl-vm app/wsl-vpnkit.service
rm wsl-vpnkit.wsl
sudo mv wsl-vpnkit wsl-gvproxy.exe wsl-vm /usr/local/bin/

# run the wsl-vpnkit script in the foreground
sudo wsl-vpnkit

# optionally setup systemd
sudo mv ./wsl-vpnkit.service /etc/systemd/system/
sudo systemctl enable wsl-vpnkit
sudo systemctl start wsl-vpnkit
systemctl status wsl-vpnkit
```

## Configuration

### Environment variables

The `wsl-vpnkit` script supports the following environment variables. For the full list, see the [`wsl-vpnkit`](wsl-vpnkit) script.

| Variable (default value) | Description |
| --- | --- |
| `DEBUG` (`0`) | Enables debug output when set to `1`. |
| `CHECK_HOST` (`host.containers.internal`) | Host name used by startup DNS diagnostics. |
| `GVPROXY_PATH` (`wsl-gvproxy.exe` from `PATH`) | Path to the `wsl-gvproxy.exe` executable. |
| `VMEXEC_PATH` (`wsl-vm` from `PATH`) | Path to the `wsl-vm` executable. |
| `WSL2_GATEWAY_IP` (detected from the default route or resolver configuration) | WSL 2 gateway IP address. |
| `WSL2_TAP_NAME` (detected route interface or `eth0`) | WSL 2 interface used to restore the default route. |
| `GVPROXY_CONFIG` (disabled) | Path to a `gvproxy` YAML configuration file. Requires `yq`. |
| `PREEXISTING` (`1`) | When `1`, `wsl-vpnkit` creates and configures a TAP interface. When `0`, `wsl-vm` creates the interface and configures it with DHCP. |

### Config file

The repository includes [`wsl-vpnkit.yaml`](wsl-vpnkit.yaml) as an example config file to use with `GVPROXY_CONFIG`.

```sh
sudo GVPROXY_CONFIG=/path/to/config.yaml PREEXISTING=0 wsl-vpnkit
```

## Troubleshooting

### Using WSL release prior to 2.4.4

Support for importing `.wsl` distro files was added in WSL release 2.4.4. If you are using an older release of WSL, this command will import the downloaded distro.

`$env:USERPROFILE\wsl-vpnkit` is the destination folder. Replace `wsl-vpnkit.wsl` with the path to the downloaded file.

```pwsh
# PowerShell

wsl --import wsl-vpnkit "$env:USERPROFILE\wsl-vpnkit" wsl-vpnkit.wsl --version 2
```

### Error messages from `wsl-vpnkit`

#### resolv.conf has been modified without setting generateResolvConf

`wsl-vpnkit` normally uses `/mnt/wsl/resolv.conf` to get the WSL 2 gateway IP. If you modify `/etc/resolv.conf` to set a custom DNS configuration, set [`generateResolvConf=false` in `wsl.conf`](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#network-settings).

On older WSL versions where `/mnt/wsl/resolv.conf` is not available, `wsl-vpnkit` will fall back to using `/etc/resolv.conf`. When set up as a standalone script and using a custom DNS configuration for the distro, the `WSL2_GATEWAY_IP` environment variable should be set for `wsl-vpnkit` to use.

#### wsl-gvproxy.exe is not executable due to WSL interop settings or Windows permissions

`wsl-vpnkit` requires the WSL 2 distro to be able to run Windows executables. The [`interop` setting](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#interop-settings) is enabled by default in WSL 2 and in the `wsl-vpnkit` distro.

If you see `cannot execute binary file: Exec format error`, check whether `/usr/lib/binfmt.d/WSLInterop.conf` exists. If it does not, generate it and restart the related service.

```sh
sudo sh -c 'echo :WSLInterop:M::MZ::/init:PF > /usr/lib/binfmt.d/WSLInterop.conf'
sudo systemctl restart systemd-binfmt
```

Security configurations on the Windows host may only permit running executables in certain directories. You can copy `wsl-gvproxy.exe` to an appropriate location and use the `GVPROXY_PATH` environment variable to specify the location.

```sh
# enable [automount] in wsl.conf for wsl-vpnkit distro
wsl.exe -d wsl-vpnkit --cd /app sed -i -- "s/enabled=false/enabled=true/" /etc/wsl.conf

# set GVPROXY_PATH when running wsl-vpnkit
wsl.exe -d wsl-vpnkit --cd /app GVPROXY_PATH=/mnt/c/path/wsl-gvproxy.exe wsl-vpnkit
```

### Configure VS Code Remote WSL Extension

If VS Code takes a long time to open your folder in WSL, [enable the setting "Connect Through Localhost"](https://github.com/microsoft/vscode-docs/blob/main/remote-release-notes/v1_54.md#fix-for-wsl-2-connection-issues-when-behind-a-proxy).

### Try shutting down WSL 2 VM to reset

```pwsh
# PowerShell

# shutdown WSL to reset networking state
wsl --shutdown

# kill any straggler wsl-gvproxy processes
kill -Name wsl-gvproxy
```

### Run service with debug

```sh
# set the DEBUG environment variable
wsl.exe -d wsl-vpnkit --cd /app DEBUG=1 wsl-vpnkit
```

## Notes

* `wsl-vpnkit` only handles creating a network connection. There may be additional configuration necessary depending on your environment.
  * For corporate DNS servers or suffixes, see [WSL network settings](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#network-settings).
  * For HTTP(S) proxies, see WSL's [`autoProxy` setting](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#considerations-when-using-autoproxy-for-httpproxy-mirroring-in-wsl). You may need to configure the proxies manually.
  * For HTTPS certificate failures, [install your organization's root CA in your distro](https://documentation.ubuntu.com/server/how-to/security/install-a-root-ca-certificate-in-the-trust-store/).
* Ports on the WSL 2 VM are [accessible from the Windows host using `localhost`](https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-linux-networking-apps-from-windows-localhost).
* Ports on the Windows host are accessible from WSL 2 using `host.containers.internal`, `192.168.127.254` or [the IP address of the host machine](https://docs.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).
* [ICMP is not forwarded outside the network](https://github.com/containers/gvisor-tap-vsock/#limitations)

## Build

The core changes `wsl-vpnkit` made to [`gvisor-tap-vsock`](https://github.com/containers/gvisor-tap-vsock) were upstreamed back to `gvisor-tap-vsock`. `wsl-vpnkit` v0.4 is a set of configurations and a shell script to execute the binaries from `gvisor-tap-vsock`. 

The Alpine build is used to package everything into one WSL 2 distro export. The Fedora and Ubuntu builds are for validating the script in different distros. Builds produce a `wsl-vpnkit.wsl` file for the host architecture.

```sh
# build with alpine image to ./wsl-vpnkit.wsl
./build.sh alpine

# build with fedora using Podman
DOCKER=podman ./build.sh fedora

# import the built distro from ./wsl-vpnkit.wsl
./import.sh

# run using the imported distro
wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit
```

## Tests

The test suite runs the `wsl-vpnkit` script in a privileged Docker container using real and mock binaries.

```sh
./tests/run.sh
```
