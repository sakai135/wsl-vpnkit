# wsl-vpnkit

The `wsl-vpnkit` script uses [VPNKit](https://github.com/moby/vpnkit) and [npiperelay](https://github.com/jstarks/npiperelay) to provide network connectivity to the WSL 2 VM while connected to VPNs on the Windows host. This requires no settings changes or admin privileges on the Windows host.

The releases bundle the script together with VPNKit and npiperelay in an [Alpine](https://alpinelinux.org/) distro.

## Setup

Download the prebuilt file `wsl-vpnkit.tar.gz` from the [latest release](https://github.com/sakai135/wsl-vpnkit/releases/latest) and import the distro into WSL 2. Running the distro will show a short intro and exit.

```pwsh
# PowerShell

wsl --import wsl-vpnkit $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz
wsl -d wsl-vpnkit
```

Start `wsl-vpnkit` from your other WSL 2 distros. Add the command to your `.profile` or `.bashrc` to start `wsl-vpnkit` when you open your WSL terminal.

```sh
# WSL vpnkit
if [ `wsl.exe -d wsl-vpnkit service wsl-vpnkit status | grep "status is 0" | wc -l` -ne 1 ]
then
    echo "Start service wsl-vpnkit"
    wsl.exe -d wsl-vpnkit service wsl-vpnkit start
fi
```

### Notes

* Ports on the WSL 2 VM are accessible from the Windows host using `localhost`.
* Ports on the Windows host are accessible from WSL 2 using `host.internal`, `192.168.67.2`, or [the IP address of the host machine](https://docs.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).

### Update

To update, unregister the existing distro and import the new version.

```pwsh
# PowerShell

wsl --unregister wsl-vpnkit
wsl --import wsl-vpnkit $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz
```

### Uninstall

To uninstall, unregister the distro.

```pwsh
# PowerShell

wsl --unregister wsl-vpnkit
rm -r $env:USERPROFILE\wsl-vpnkit
```

### Build

This will build and import the distro.

```sh
git clone https://github.com/sakai135/wsl-vpnkit.git
cd wsl-vpnkit/

./distro/test.sh
```

## Using `wsl-vpnkit` as a standalone script

The `wsl-vpnkit` script can be used as a normal script in your existing distro. This is an example setup script for Ubuntu.

```sh
USERPROFILE=$(wslpath "$(powershell.exe -c 'Write-Host -NoNewline $env:USERPROFILE')")
mkdir -p "$USERPROFILE/wsl-vpnkit"

sudo apt install p7zip-full socat

wget https://desktop.docker.com/win/stable/amd64/67351/Docker%20Desktop%20Installer.exe
7z e Docker\ Desktop\ Installer.exe resources/vpnkit.exe resources/wsl/docker-for-wsl.iso
7z e docker-for-wsl.iso containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd
rm Docker\ Desktop\ Installer.exe docker-for-wsl.iso
mv vpnkit.exe "$USERPROFILE/wsl-vpnkit/wsl-vpnkit.exe"
chmod +x vpnkit-tap-vsockd
sudo chown root:root vpnkit-tap-vsockd
sudo mv vpnkit-tap-vsockd /usr/local/sbin/vpnkit-tap-vsockd

wget https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip
7z e npiperelay_windows_amd64.zip npiperelay.exe
rm npiperelay_windows_amd64.zip
mv npiperelay.exe "$USERPROFILE/wsl-vpnkit/"

sudo ./wsl-vpnkit
```

## Troubleshooting

### Configure VS Code Remote WSL Extension

If VS Code takes a long time to open your folder in WSL, [enable the setting "Connect Through Localhost"](https://github.com/microsoft/vscode-docs/blob/main/remote-release-notes/v1_54.md#fix-for-wsl-2-connection-issues-when-behind-a-proxy).

### Try shutting down WSL 2 VM to reset

```pwsh
# PowerShell

wsl --shutdown
kill -Name wsl-vpnkit
```
