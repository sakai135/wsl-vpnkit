# wsl-vpnkit

`wsl-vpnkit` provides network connectivity for WSL 2 when your Windows VPN blocks access. This requires no setting changes or admin privileges on the Windows host to use.

For previous versions, see [v0.3](https://github.com/sakai135/wsl-vpnkit/tree/v0.3.x) and [v0.2](https://github.com/sakai135/wsl-vpnkit/tree/v0.2.x).

## Setup

Before setting up `wsl-vpnkit`, try `ping 1.2.3.4` inside WSL 2. If the pings are successful, follow the steps in [WSL has no network connectivity once connected to a VPN](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#wsl-has-no-network-connectivity-once-connected-to-a-vpn). WSL2 networking options like [mirrored mode](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking) and other [`.wslconfig` options](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#wslconfig) may resolve your issue as well.

`wsl-vpnkit` is intended to help when those options do not work.

### Install `wsl-vpnkit` distro

Download `wsl-vpnkit.wsl` from the [latest release](https://github.com/sakai135/wsl-vpnkit/releases/latest) and open it to import the distro into WSL 2. 

Run `wsl-vpnkit`. This starts `wsl-vpnkit` in the foreground.

```sh
wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit
```

#### Setup systemd

Create the service file and enable the service. Now `wsl-vpnkit.service` should start with your distro next time.

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

### Install as a standalone script

The `wsl-vpnkit` script can be used as a normal script in your existing distro. This is an example setup script for Ubuntu.

```sh
# install dependencies
sudo apt-get install iproute2 iptables iputils-ping dnsutils wget

# download wsl-vpnkit and unpack
VERSION=v0.4.x
wget wget https://github.com/sakai135/wsl-vpnkit/releases/download/$VERSION/wsl-vpnkit-amd64.wsl -O wsl-vpnkit.wsl
tar --strip-components=1 -xf wsl-vpnkit.wsl app/wsl-vpnkit app/wsl-gvproxy.exe app/wsl-vm app/wsl-vpnkit.service
rm wsl-vpnkit.wsl
sudo mv wsl-vpnkit wsl-gvproxy.exe wsl-vm /usr/local/bin/

# run the wsl-vpnkit script in the foreground
sudo wsl-vpnkit

# setup systemd
sudo mv ./wsl-vpnkit.service /etc/systemd/system/
sudo systemctl enable wsl-vpnkit
sudo systemctl start wsl-vpnkit
systemctl status wsl-vpnkit
```

## Troubleshooting

### Error messages from `wsl-vpnkit`

#### resolv.conf has been modified without setting generateResolvConf

`wsl-vpnkit` uses `/mnt/wsl/resolv.conf` to get the WSL 2 gateway IP. If modifying `/etc/resolv.conf` to set a custom DNS configuration, set [`generateResolvConf=false` in `wsl.conf`](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#network-settings).

On older WSL versions where `/mnt/wsl/resolv.conf` is not available, `wsl-vpnkit` will fallback to using `/etc/resolv.conf`. When setup as a standalone script and using a custom DNS configuration for the distro, the `WSL2_GATEWAY_IP` environment variable should be set for `wsl-vpnkit` to use.

#### wsl-gvproxy.exe is not executable due to WSL interop settings or Windows permissions

`wsl-vpnkit` requires that the WSL 2 distro be able to run Windows executables. This [`interop` setting](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#interop-settings) is enabled by default in WSL 2 and in the `wsl-vpnkit` distro.
* To resolve `cannot execute binary file: Exec format error`, please check for the existence of this file: `/usr/lib/binfmt.d/WSLInterop.conf`
  * If the file is not found, run this to generate it and restart the related service:
    ```
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

### Using WSL release prior to 2.4.4

Use this command to import the downloaded distro.

```pwsh
# PowerShell

wsl --import wsl-vpnkit --version 2 "$env:USERPROFILE\wsl-vpnkit" wsl-vpnkit.wsl
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

* `wsl-vpnkit` only handles creating a network connection. Proxies and certificates must be configured separately in your distro.
* Ports on the WSL 2 VM are [accessible from the Windows host using `localhost`](https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-linux-networking-apps-from-windows-localhost).
* Ports on the Windows host are accessible from WSL 2 using `host.containers.internal`, `192.168.127.254` or [the IP address of the host machine](https://docs.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).

## Build

The core changes `wsl-vpnkit` made to `gvisor-tap-vsock` were upstreamed back to `gvisor-tap-vsock`. `wsl-vpnkit` is a set of configurations and shell script to execute the binaries from `gvisor-tap-vsock`. 

The Alpine build is used to package everything into one WSL2 distro export. The Fedora and Ubuntu builds are for validating the script in different distros. 

```sh
# build with alpine image to ./wsl-vpnkit.tar.gz
./build.sh alpine

# build with fedora using Podman
DOCKER=podman ./build.sh fedora

# import the built distro from ./wsl-vpnkit.tar.gz
./import.sh

# run using the imported distro
wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit
```
