# wsl-vpnkit

The `wsl-vpnkit` v0.4 script uses [gvisor-tap-vsock](https://github.com/containers/gvisor-tap-vsock) to provide network connectivity to the WSL 2 VM while connected to VPNs on the Windows host. This requires no settings changes or admin privileges on the Windows host.

For previous versions, see [v0.3](https://github.com/sakai135/wsl-vpnkit/tree/v0.3.x) and [v0.2](https://github.com/sakai135/wsl-vpnkit/tree/v0.2.x).

## Setup

Before setting up `wsl-vpnkit`, check if a DNS server change may be enough to get connectivity by pinging a public IP address from WSL 2. If that works, follow the steps in [WSL has no network connectivity once connected to a VPN](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#wsl-has-no-network-connectivity-once-connected-to-a-vpn).

`wsl-vpnkit` is intended to help when more than a DNS server change is needed.

### Setup as a distro

#### Install

Download the prebuilt file `wsl-vpnkit.tar.gz` from the [latest release](https://github.com/sakai135/wsl-vpnkit/releases/latest) and import the distro into WSL 2. 

```pwsh
# PowerShell

wsl --import wsl-vpnkit --version 2 $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz
```

Run `wsl-vpnkit`. This will run `wsl-vpnkit` in the foreground.

```sh
wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit
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
sudo apt-get install iproute2 iptables iputils-ping dnsutils wget

# download wsl-vpnkit and unpack
VERSION=v0.4.1
wget https://github.com/sakai135/wsl-vpnkit/releases/download/$VERSION/wsl-vpnkit.tar.gz
tar --strip-components=1 -xf wsl-vpnkit.tar.gz \
    app/wsl-vpnkit \
    app/wsl-gvproxy.exe \
    app/wsl-vm \
    app/wsl-vpnkit.service
rm wsl-vpnkit.tar.gz

# run the wsl-vpnkit script in the foreground
sudo VMEXEC_PATH=$(pwd)/wsl-vm GVPROXY_PATH=$(pwd)/wsl-gvproxy.exe ./wsl-vpnkit
```

### Setup systemd

WSL versions 0.67.6 and later [support systemd](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#systemd-support). Follow the instructions in the link to enable systemd support for your distro.

Create the service file and enable the service. Now `wsl-vpnkit.service` should start with your distro next time.

```sh
# wsl-vpnkit setup as a distro
wsl.exe -d wsl-vpnkit --cd /app cat /app/wsl-vpnkit.service | sudo tee /etc/systemd/system/wsl-vpnkit.service

# copy and edit for wsl-vpnkit setup as a standalone script
sudo cp ./wsl-vpnkit.service /etc/systemd/system/
sudo nano /etc/systemd/system/wsl-vpnkit.service

# enable the service
sudo systemctl enable wsl-vpnkit

# start and check the status of the service
sudo systemctl start wsl-vpnkit
systemctl status wsl-vpnkit
```

## Build


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

## Troubleshooting

### Notes

* Ports on the WSL 2 VM are [accessible from the Windows host using `localhost`](https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-linux-networking-apps-from-windows-localhost).
* Ports on the Windows host are accessible from WSL 2 using `host.containers.internal`, `192.168.127.254` or [the IP address of the host machine](https://docs.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).

### Error messages from `wsl-vpnkit`

#### resolv.conf has been modified without setting generateResolvConf

`wsl-vpnkit` uses `/mnt/wsl/resolv.conf` to get the WSL 2 gateway IP. If modifying `/etc/resolv.conf` to set a custom DNS configuration, set [`generateResolvConf=false` in `wsl.conf`](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#network-settings).

On older WSL versions where `/mnt/wsl/resolv.conf` is not available, `wsl-vpnkit` will fallback to using `/etc/resolv.conf`. When setup as a standalone script and using a custom DNS configuration for the distro, the `WSL2_GATEWAY_IP` environment variable should be set for `wsl-vpnkit` to use.

#### wsl-gvproxy.exe is not executable due to WSL interop settings or Windows permissions

`wsl-vpnkit` requires that the WSL 2 distro be able to run Windows executables. This [`interop` setting](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#interop-settings) is enabled by default in WSL 2 and in the `wsl-vpnkit` distro.

Security configurations on the Windows host may only permit running executables in certain directories. You can copy `wsl-gvproxy.exe` to an appropriate location and use the `GVPROXY_PATH` environment variable to specify the location.
`GVPROXY_PATH` must point to a /mnt folder for wsl-gvproxy.exe to work!

```sh
# enable [automount] in wsl.conf for wsl-vpnkit distro
# Please be sure the [automount] section exists
wsl.exe -d wsl-vpnkit --cd /app sed -i -- "s/enabled=false/enabled=true/" /etc/wsl.conf

# set GVPROXY_PATH when running wsl-vpnkit to a /mnt directory (it must reside on windows host filesystem)
wsl.exe -d wsl-vpnkit --cd /app GVPROXY_PATH=/mnt/c/path/wsl-gvproxy.exe wsl-vpnkit
```

### Configuring proxies and certificates

`wsl-vpnkit` currently only handles creating a network connection. Proxies and certificates must be configured separately in your distro.

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
