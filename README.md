# wsl-vpnkit

The `wsl-vpnkit` v0.3 script uses [gvisor-tap-vsock](https://github.com/containers/gvisor-tap-vsock) to provide network connectivity to the WSL 2 VM while connected to VPNs on the Windows host. This requires no settings changes or admin privileges on the Windows host.

The releases bundle the script together with the binaries in an [Alpine](https://alpinelinux.org/) distro.

For v0.2, please see the [v0.2.x branch](https://github.com/sakai135/wsl-vpnkit/tree/v0.2.x).

## Setup

Download the prebuilt file `wsl-vpnkit.tar.gz` from the [latest release](https://github.com/sakai135/wsl-vpnkit/releases/latest) and import the distro into WSL 2. Running the distro will show a short intro and exit.

```pwsh
# PowerShell

wsl --import wsl-vpnkit $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz --version 2
wsl -d wsl-vpnkit
```

Start `wsl-vpnkit` from your other WSL 2 distros. Add the command to your `.profile` or `.bashrc` to start `wsl-vpnkit` when you open your WSL terminal.

```sh
wsl.exe -d wsl-vpnkit service wsl-vpnkit start
```

### Notes

* Ports on the WSL 2 VM are accessible from the Windows host using `localhost`.
* Ports on the Windows host are accessible from WSL 2 using `host.internal`, `192.168.67.2` or [the IP address of the host machine](https://docs.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).

### Update

To update, unregister the existing distro and import the new version.

```pwsh
# PowerShell

wsl --unregister wsl-vpnkit
wsl --import wsl-vpnkit $env:USERPROFILE\wsl-vpnkit wsl-vpnkit.tar.gz --version 2
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
# download wsl-vpnkit
VERSION=v0.3.x
wget https://github.com/sakai135/wsl-vpnkit/releases/download/$VERSION/wsl-vpnkit.tar.gz
tar --strip-components=1 -xf wsl-vpnkit.tar.gz app/wsl-vpnkit files/wsl-gvproxy.exe files/wsl-vm
rm wsl-vpnkit.tar.gz

# place Windows exe
USERPROFILE=$(wslpath "$(powershell.exe -c 'Write-Host -NoNewline $env:USERPROFILE')")
mkdir -p "$USERPROFILE/wsl-vpnkit"
mv wsl-gvproxy.exe "$USERPROFILE/wsl-vpnkit/wsl-gvproxy.exe"

# place Linux bin
chmod +x wsl-vm
sudo chown root:root wsl-vm
sudo mv wsl-vm /usr/local/sbin/wsl-vm

# run the wsl-vpnkit script
chmod +x wsl-vpnkit
sudo ./wsl-vpnkit
```

## Troubleshooting

### Configure VS Code Remote WSL Extension

If VS Code takes a long time to open your folder in WSL, [enable the setting "Connect Through Localhost"](https://github.com/microsoft/vscode-docs/blob/main/remote-release-notes/v1_54.md#fix-for-wsl-2-connection-issues-when-behind-a-proxy).

### Cannot connect to WSL 2 VM IP while connected to VPN

This is due to the VPN blocking connections to the WSL 2 VM network interface. Ports on the WSL 2 VM are accessible from the Windows host using `localhost`.

For this and other networking considerations when using WSL 2, see [Accessing network applications with WSL](https://docs.microsoft.com/en-us/windows/wsl/networking).

### Run in foreground

```sh
wsl.exe -d wsl-vpnkit wsl-vpnkit
```

### Try shutting down WSL 2 VM to reset

```pwsh
# PowerShell

wsl --shutdown
kill -Name wsl-gvproxy
```
