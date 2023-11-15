# wsl-vpnkit

The `wsl-vpnkit` provides network connectivity to WSL 2 VM's while connected to a VPN on the Windows host. No admin privileges or setting changes are required.

The script uses [gvisor-tap-vsock](https://github.com/containers/gvisor-tap-vsock) under the hood.

## Previous Versions

For previous versions see:

[v0.3](https://github.com/sakai135/wsl-vpnkit/tree/v0.3.x)

[v0.2](https://github.com/sakai135/wsl-vpnkit/tree/v0.2.x)

## Before Installing

Before setting up `wsl-vpnkit`, check if a DNS server change may be enough to get connectivity by pinging a public IP address from WSL 2. If that works, follow the steps in [WSL has no network connectivity once connected to a VPN](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#wsl-has-no-network-connectivity-once-connected-to-a-vpn).

`wsl-vpnkit` is intended to help when more than a DNS server change is needed.

## Installation

There are two primary ways to install `wsl-vpnkit`. Either as a WSL Distribution or as a standalone script within an existing WSL VM.

### As a WSL Distribution

Download the prebuilt file `wsl-vpnkit.tar.gz` from the [latest release](https://github.com/sakai135/wsl-vpnkit/releases/latest)

Import the archive as a WSL 2 Distro:

```powershell
# PowerShell on Windows host

# Make sure to navigate to the directory containing wsl-vpnkit.tar.gz

wsl --import wsl-vpnkit --version 2 $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz
```

To check if the import was successful you can run the new `wsl-vpnkit` vm in the foreground:

```powershell
# PowerShell on Windows host

wsl -d wsl-vpnkit --cd /app wsl-vpnkit
```

#### Add as a Service to Existing WSL VM's Using Systemd

Systemd is enabled by default in newer WSL versions. Should you be working with an older VM you might have to enable it manually. See: [support systemd](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#systemd-support)

```sh
# In WSL2 distro lacking network connectivity

# If you are uncertain if systemd is enabled you can check with:
ps -p 1 -o comm=
# output should be: systemd
```

To enable `wsl-vpnkit` as a service in an existing WSL2 Distribution (for example Ubuntu) follow these steps:

```sh
# In WSL2 Distro lacking network connectivity

#Copy systemd service definition from wsl-vpnkit
wsl.exe -d wsl-vpnkit --cd /app cat /app/wsl-vpnkit.service | sudo tee /etc/systemd/system/wsl-vpnkit.service

# enable the service
sudo systemctl enable wsl-vpnkit

# start and check the status of the service
sudo systemctl start wsl-vpnkit
systemctl status wsl-vpnkit
```

At this point the installation should be fully operational. `wsl-vpnkit` should start with your WSL 2 VM and there should be notwork connectivity.

#### Update

To update you version of `wsl-vpnkit` you can just remove the current distro and import the updated version:

```powershell
# PowerShell on Windows host

wsl --unregister wsl-vpnkit
wsl --import wsl-vpnkit --version 2 $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz
```

#### Uninstall

To uninstall just unregister the distro:

```powershell
# PowerShell on Windows host

wsl --unregister wsl-vpnkit
```

### As a Standalone Script

The `wsl-vpnkit` script can be used as a normal script in your existing distro. This is an example setup script for Ubuntu.

```sh
# In existing Ubuntu VM

# install dependencies
sudo apt-get install iproute2 iptables iputils-ping dnsutils wget

# download wsl-vpnkit and unpack
VERSION=v0.4.x
wget https://github.com/sakai135/wsl-vpnkit/releases/download/$VERSION/wsl-vpnkit.tar.gz
tar --strip-components=1 -xf wsl-vpnkit.tar.gz \
    app/wsl-vpnkit \
    app/wsl-gvproxy.exe \
    app/wsl-vm \
    app/wsl-vpnkit.service
rm wsl-vpnkit.tar.gz

# run the wsl-vpnkit script manually
sudo VMEXEC_PATH=$(pwd)/wsl-vm GVPROXY_PATH=$(pwd)/wsl-gvproxy.exe ./wsl-vpnkit
```

#### Add as a Systemd Service

```sh
# In existing Ubuntu VM

# Copy the service definition
sudo cp ./wsl-vpnkit.service /etc/systemd/system/

# Edit the service file,
# Remove distro ExecStart and uncomment the indicated lines for standalone script.
# Update the file paths as appropriate.
sudo nano /etc/systemd/system/wsl-vpnkit.service

# enable the service
sudo systemctl enable wsl-vpnkit

# start and check the status of the service
sudo systemctl start wsl-vpnkit
systemctl status wsl-vpnkit
```

At this point the installation should be fully operational. `wsl-vpnkit` should start with your WSL 2 VM and there should be notwork connectivity.

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

- Ports on the WSL 2 VM are [accessible from the Windows host using `localhost`](https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-linux-networking-apps-from-windows-localhost).
- Ports on the Windows host are accessible from WSL 2 using `host.containers.internal`, `192.168.127.254` or [the IP address of the host machine](https://docs.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).

### Error messages from `wsl-vpnkit`

#### resolv.conf has been modified without setting generateResolvConf

`wsl-vpnkit` uses `/mnt/wsl/resolv.conf` to get the WSL 2 gateway IP. If modifying `/etc/resolv.conf` to set a custom DNS configuration, set [`generateResolvConf=false` in `wsl.conf`](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#network-settings).

On older WSL versions where `/mnt/wsl/resolv.conf` is not available, `wsl-vpnkit` will fallback to using `/etc/resolv.conf`. When setup as a standalone script and using a custom DNS configuration for the distro, the `WSL2_GATEWAY_IP` environment variable should be set for `wsl-vpnkit` to use.

#### wsl-gvproxy.exe is not executable due to WSL interop settings or Windows permissions

`wsl-vpnkit` requires that the WSL 2 distro be able to run Windows executables. This [`interop` setting](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#interop-settings) is enabled by default in WSL 2 and in the `wsl-vpnkit` distro.

Security configurations on the Windows host may only permit running executables in certain directories. You can copy `wsl-gvproxy.exe` to an appropriate location and use the `GVPROXY_PATH` environment variable to specify the location.

```sh
# enable [automount] in wsl.conf for wsl-vpnkit distro
wsl.exe -d wsl-vpnkit --cd /app sed -i -- "s/enabled=false/enabled=true/" /etc/wsl.conf

# set GVPROXY_PATH when running wsl-vpnkit
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
