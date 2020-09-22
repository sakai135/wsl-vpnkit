# wsl-vpnkit

Uses VPNKit to provide network connectivity to the WSL2 VM through the host's VPN.

## Prerequisites

This currently expects for [Docker Desktop for Windows](https://hub.docker.com/editions/community/docker-ce-desktop-windows/) to be installed for the executable `vpnkit.exe` and its configuration files `http_proxy.json` and `gateway_forwards.json` to exist. `vpnkit.exe` can be built from [VPNKit](https://github.com/moby/vpnkit) instead if Docker Desktop is not installed.

## Setup

### Install `vpnkit-tap-vsockd`

Extract from Docker Desktop for Windows.

```sh
sudo apt install genisoimage
```

```sh
isoinfo -i /mnt/c/Program\ Files/Docker/Docker/resources/wsl/docker-for-wsl.iso -R -x /containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd > ./vpnkit-tap-vsockd
chmod +x vpnkit-tap-vsockd
sudo mv vpnkit-tap-vsockd /sbin/vpnkit-tap-vsockd
sudo chown root:root /sbin/vpnkit-tap-vsockd
```

Alternatively, build from [VPNKit](https://github.com/moby/vpnkit).

### Install `npiperelay.exe`

Download from [npiperelay](https://github.com/jstarks/npiperelay).

```sh
sudo apt install unzip
```

```sh
wget https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip
unzip npiperelay_windows_amd64.zip npiperelay.exe
rm npiperelay_windows_amd64.zip
mkdir /mnt/c/bin
mv npiperelay.exe /mnt/c/bin/
sudo ln -s /mnt/c/bin/npiperelay.exe /usr/local/bin/npiperelay.exe
```

### Install `socat`

```sh
sudo apt install socat
```

### Configure WSL Distro

```sh
cat <<EOL
[network]
generateResolvConf = false
EOL | sudo tee /etc/wsl.conf
```

```sh
sudo unlink /etc/resolv.conf
cat <<EOL
nameserver 192.168.67.1
EOL | sudo tee /etc/resolv.conf
```

### Configure `http_proxy.json` and `gateway_forwards.json`

Docker Desktop will automatically generate and update `http_proxy.json` and `gateway_forwards.json`. If Docker Desktop is not running, create these configuration files. 

`http_proxy.json` points to any HTTP proxies that might be configured on the Windows host. Use an empty object `{}` as its value for no proxy.

`gateway_forwards.json` points to any services to forward to the WSL2 VM. DNS should be configured here. See an [example from VPNKit](https://github.com/moby/vpnkit/blob/bfd0458bb811027cb9bd45f9ed8d63984b5d4a33/go/pkg/vpnkit/config_test.go#L28).

### Configure VS Code Remote WSL Extension

This is an optional workaround if the VPN on the Windows host blocks connections to the WSL2 VM and VS Code takes a while to open files within WSL2.

`~\.vscode\extensions\ms-vscode-remote.remote-wsl-0.44.5\dist\wslDaemon.js`

Look for something like this:

```js
async function P(e,t,s){if(l.isWSL1(s))return"127.0.0.1";}
```

Insert `::1` to force use of IPv6 localhost:

```js
async function P(e,t,s){return"::1";if(l.isWSL1(s))return"127.0.0.1";}
```

## Run

```sh
sudo ./wsl-vpnkit
```

Keep this terminal open.

## Troubleshooting

### Try shutting down WSL VM to reset

```sh
wsl.exe --shutdown
```

Check for a `vpnkit.exe` process listening on `\\.\pipe\wsl-vpnkit` and kill that too.

### Check for the required processes

```sh
ps aux | grep wsl-vpnkit
```

* `socat ... npiperelay.exe`
* `vpnkit.exe`
* `vpnkit-tap-vsockd`
