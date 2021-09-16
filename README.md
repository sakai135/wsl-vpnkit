# wsl-vpnkit

Uses [VPNKit](https://github.com/moby/vpnkit) and [npiperelay](https://github.com/jstarks/npiperelay) to provide network connectivity to the WSL 2 VM. This requires no settings changes or admin privileges on the Windows host.

## Setup

The following steps will use WSL to setup `wsl-vpnkit`. If you do not have connectivity in WSL 2, you can [switch your WSL version](https://docs.microsoft.com/en-us/windows/wsl/install-win10#set-your-distribution-version-to-wsl-1-or-wsl-2) to WSL 1 for setup and back to WSL 2 once done. Alternatively, you can refer to [this post to setup `wsl-vpnkit` from the Windows side](https://github.com/sakai135/wsl-vpnkit/issues/11#issuecomment-777806102).

### Install `vpnkit.exe` and `vpnkit-tap-vsockd`

This will download and extract `vpnkit.exe` and `vpnkit-tap-vsockd` from the [Docker Desktop for Windows installer](https://docs.docker.com/docker-for-windows/install/). Alternatively, build `vpnkit.exe` and `vpnkit-tap-vsockd` from [VPNKit](https://github.com/moby/vpnkit).

```sh
sudo apt install p7zip-full
```

```sh
wget https://desktop.docker.com/win/stable/amd64/67351/Docker%20Desktop%20Installer.exe
7z e Docker\ Desktop\ Installer.exe resources/vpnkit.exe resources/wsl/docker-for-wsl.iso
7z e docker-for-wsl.iso containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd
rm Docker\ Desktop\ Installer.exe docker-for-wsl.iso

mkdir -p /mnt/c/bin
mv vpnkit.exe /mnt/c/bin/wsl-vpnkit.exe

chmod +x vpnkit-tap-vsockd
sudo chown root:root vpnkit-tap-vsockd
sudo mv vpnkit-tap-vsockd /usr/local/sbin/vpnkit-tap-vsockd
```

### Install `npiperelay.exe`

Download from [npiperelay](https://github.com/jstarks/npiperelay).

```sh
wget https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip
7z e npiperelay_windows_amd64.zip npiperelay.exe
rm npiperelay_windows_amd64.zip

mkdir -p /mnt/c/bin
mv npiperelay.exe /mnt/c/bin/
```

### Install `socat`

```sh
sudo apt install socat
```

### Configure DNS for WSL

Disable WSL from generating and overwriting `/etc/resolv.conf` with the [network options in `wsl.conf`](https://docs.microsoft.com/en-us/windows/wsl/wsl-config#network).

```sh
sudo tee /etc/wsl.conf <<EOL
[network]
generateResolvConf = false
EOL
```

Shutdown the WSL2 VM and reopen your shell for `wsl.conf` to take effect.

```sh
wsl.exe --shutdown
```

Manually set DNS servers to use when not running `wsl-vpnkit`. [`1.1.1.1`](https://1.1.1.1/dns/) is provided here as an example.

```sh
sudo tee /etc/resolv.conf <<EOL
nameserver 1.1.1.1
EOL
```

### Clone `wsl-vpnkit`

```sh
git clone https://github.com/sakai135/wsl-vpnkit.git
cd wsl-vpnkit/
```

## Run

```sh
sudo ./wsl-vpnkit
```

Keep this terminal open.

In some environments, explicitly pass the environment variable `WSL_INTEROP` to `sudo`.

```sh
sudo --preserve-env=WSL_INTEROP ./wsl-vpnkit
```

Services on the WSL 2 VM should be accessible from the Windows host using `localhost` through [the WSL networking integrations](https://devblogs.microsoft.com/commandline/whats-new-for-wsl-in-insiders-preview-build-18945/#use-localhost-to-connect-to-your-linux-applications-from-windows) which can be configured by the [`localhostForwarding` option in `.wslconfig`](https://docs.microsoft.com/en-us/windows/wsl/wsl-config#wsl-2-settings). Services on the Windows host should be accessible from WSL 2 using the IP from `VPNKIT_HOST_IP` (`192.168.67.2`).

## Run in the Background

This uses `wsl.exe` and `start-stop-daemon` to run `wsl-vpnkit` in the background. A log file will be created at `/var/log/wsl-vpnkit.log` with the output from `wsl-vpnkit`.

```sh
sudo ./wsl-vpnkit.service start
```

## Run as a Service

This is an example setup to run `wsl-vpnkit` as a service.

### Create Service

```sh
sudo ln -s $(pwd)/wsl-vpnkit.service /etc/init.d/wsl-vpnkit
```

### Setup Sudoers

This allows running the `wsl-vpnkit` service without entering a password every time.

This step can be dangerous. Read [Sudoers](https://help.ubuntu.com/community/Sudoers) before doing this step.

```sh
sudo visudo -f /etc/sudoers.d/wsl-vpnkit
```

```
yourusername ALL=(ALL) NOPASSWD: /usr/sbin/service wsl-vpnkit *
```

### Run Automatically

Add the following to your `.profile` or `.bashrc` to start `wsl-vpnkit` when you open your WSL terminal.

```sh
sudo service wsl-vpnkit start
```

## Troubleshooting

### Configure VS Code Remote WSL Extension

If VS Code takes a long time to open your folder in WSL, [enable the setting "Connect Through Localhost"](https://github.com/microsoft/vscode-docs/blob/main/remote-release-notes/v1_54.md#fix-for-wsl-2-connection-issues-when-behind-a-proxy).

### Try shutting down WSL VM to reset

```sh
wsl.exe --shutdown
```

```powershell
Stop-Process -Name wsl-vpnkit
```

### Check for the required processes

```sh
ps aux | grep wsl-vpnkit
```

* `socat ... npiperelay.exe`
* `wsl-vpnkit.exe`
* `vpnkit-tap-vsockd`

### Run VPNKit with Debug

```sh
sudo VPNKIT_DEBUG=1 ./wsl-vpnkit
```
