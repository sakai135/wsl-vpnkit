# wsl-vpnkit

The `wsl-vpnkit` v0.4 script uses [gvisor-tap-vsock](https://github.com/containers/gvisor-tap-vsock) to provide network connectivity to the WSL 2 VM while connected to VPNs on the Windows host. This requires no settings changes or admin privileges on the Windows host.

TODO: add about upgrading from v0.3

For v0.2, please see the [v0.2.x branch](https://github.com/sakai135/wsl-vpnkit/tree/v0.2.x).

## Setup

### Setup as a distro

#### Install

Download the prebuilt file `wsl-vpnkit.tar.gz` from the [latest release](https://github.com/sakai135/wsl-vpnkit/releases/latest) and import the distro into WSL 2. 

```pwsh
# PowerShell

wsl --import wsl-vpnkit --version 2 $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz
```

Start `wsl-vpnkit` from your other WSL 2 distros. This will run `wsl-vpnkit` in the foreground. 

```sh
wsl.exe -d wsl-vpnkit wsl-vpnkit
```

#### Update

To update, unregister the existing distro and import the new version.

```pwsh
# PowerShell

wsl --unregister wsl-vpnkit
wsl --import wsl-vpnkit --version 2 $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz
```

#### Uninstall

To uninstall, unregister the distro.

```pwsh
# PowerShell

wsl --unregister wsl-vpnkit
```

### Setup as a standalone script

The `wsl-vpnkit` script can be used as a normal script in your existing distro. This is an example setup script for Ubuntu.

```sh
# install dependencies
apt-get install isc-dhcp-client iproute2 iptables iputils-ping dnsutils wget

# download wsl-vpnkit and unpack
VERSION=v0.4.x
wget https://github.com/sakai135/wsl-vpnkit/releases/download/$VERSION/wsl-vpnkit.tar.gz
tar --strip-components=1 -xf wsl-vpnkit.tar.gz usr/bin/wsl-vpnkit app/wsl-gvproxy.exe usr/bin/wsl-vm
rm wsl-vpnkit.tar.gz

# place Linux bin
chmod +x wsl-vm
sudo chown root:root wsl-vm
sudo mv wsl-vm /usr/local/sbin/wsl-vm

# run the wsl-vpnkit script in the foreground
chmod +x wsl-vpnkit
sudo GVPROXY_PATH=$(pwd)/wsl-gvproxy.exe ./wsl-vpnkit
```

### Setup systemd

WSL versions 0.67.6 and later [support systemd](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#systemd-support). Follow the instructions in the link to enable systemd support for your distro.

Create the service file. `wsl-vpnkit.service` is provided in the repo to work when wsl-vpnkit is setup as a distro. 

```sh
# wsl-vpnkit setup as a distro
wsl.exe -d wsl-vpnkit cat /app/wsl-vpnkit.service | sudo tee /etc/systemd/system/wsl-vpnkit.service
```

If wsl-vpnkit is setup as a standalone script, please edit values in `wsl-vpnkit.service` to fit your environment.

```sh
# edit for wsl-vpnkit setup as a standalone script
sudo nano /etc/systemd/system/wsl-vpnkit.service
```

Enable the service. Now `wsl-vpnkit.service` should start with your distro next time.
```sh
sudo systemctl enable wsl-vpnkit.service

sudo systemctl start wsl-vpnkit.service
systemctl status wsl-vpnkit.service
```

## Notes

* Ports on the WSL 2 VM are [accessible from the Windows host using `localhost`](https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-linux-networking-apps-from-windows-localhost).
* Ports on the Windows host are accessible from WSL 2 using `host.containers.internal`, `192.168.127.254` or [the IP address of the host machine](https://docs.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).

## Build

### Build the distro

This will build and import the distro.

```sh
git clone https://github.com/sakai135/wsl-vpnkit.git
cd wsl-vpnkit/

./build.sh alpine
./import.sh

wsl.exe -d wsl-vpnkit wsl-vpnkit
```

Optionally you may build with `podman` instead of `docker` (default) by overriding environment variable `DOCKER`:
```sh
DOCKER=podman ./build.sh alpine
```

## Troubleshooting

### Configure VS Code Remote WSL Extension

If VS Code takes a long time to open your folder in WSL, [enable the setting "Connect Through Localhost"](https://github.com/microsoft/vscode-docs/blob/main/remote-release-notes/v1_54.md#fix-for-wsl-2-connection-issues-when-behind-a-proxy).

### Cannot connect to WSL 2 VM IP while connected to VPN

This is due to the VPN blocking connections to the WSL 2 VM network interface. Ports on the WSL 2 VM are accessible from the Windows host using `localhost`.

For this and other networking considerations when using WSL 2, see [Accessing network applications with WSL](https://docs.microsoft.com/en-us/windows/wsl/networking).

### Try shutting down WSL 2 VM to reset

```pwsh
# PowerShell

wsl --shutdown
kill -Name wsl-gvproxy
```

### Run service with debug

Set the DEBUG environment variable to display debug information.

Example:
```sh
wsl.exe -d wsl-vpnkit DEBUG=1 wsl-vpnkit
```
