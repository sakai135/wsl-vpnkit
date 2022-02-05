# wsl-vpnkit

The `wsl-vpnkit` script uses [gvisor-tap-vsock](https://github.com/containers/gvisor-tap-vsock) to provide network connectivity to the WSL 2 VM while connected to VPNs on the Windows host. This requires no settings changes or admin privileges on the Windows host.

The releases bundle the script together with modified gvisor-tap-vsock binaries in an [Alpine](https://alpinelinux.org/) distro.

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
* Ports on the Windows host are accessible from WSL 2 using `192.168.67.2` or [the IP address of the host machine](https://docs.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).

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
# create the directory to place Windows executables
USERPROFILE=$(wslpath "$(powershell.exe -c 'Write-Host -NoNewline $env:USERPROFILE')")
mkdir -p "$USERPROFILE/wsl-vpnkit"

# download binaries
wget https://github.com/sakai135/vpnkit/releases/download/v0.5.0-20211026/vpnkit-tap-vsockd
wget https://github.com/sakai135/vpnkit/releases/download/v0.5.0-20211026/vpnkit.exe
mv wsl-gvproxy.exe "$USERPROFILE/wsl-vpnkit/wsl-gvproxy.exe"
chmod +x wsl-vm
sudo chown root:root wsl-vm
sudo mv wsl-vm /usr/local/sbin/wsl-vm

# download the wsl-vpnkit script to current directory
wget https://raw.githubusercontent.com/sakai135/wsl-vpnkit/main/wsl-vpnkit
chmod +x wsl-vpnkit

# run the wsl-vpnkit script
sudo ./wsl-vpnkit
```

## Troubleshooting

### Configure VS Code Remote WSL Extension

If VS Code takes a long time to open your folder in WSL, [enable the setting "Connect Through Localhost"](https://github.com/microsoft/vscode-docs/blob/main/remote-release-notes/v1_54.md#fix-for-wsl-2-connection-issues-when-behind-a-proxy).

### Try shutting down WSL 2 VM to reset

```pwsh
# PowerShell

wsl --shutdown
kill -Name wsl-gvproxy
```
