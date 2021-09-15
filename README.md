# wsl-vpnkit

Uses [VPNKit](https://github.com/moby/vpnkit) and [npiperelay](https://github.com/jstarks/npiperelay) bundled in an [Alpine](https://alpinelinux.org/) distro to provide network connectivity to the WSL 2 VM while connected to restrictive VPNs on the Windows host. This requires no settings changes or admin privileges on the Windows host.

## Install

Download and then import the `wsl-vpnkit` distro. This will install `wsl-vpnkit` as a separate WSL 2 distro. Running the distro will show a short intro and exit.

```ps
wsl --import wsl-vpnkit $env:USERPROFILE\wsl-vpnkit .\wsl-vpnkit.tar.gz
wsl -d wsl-vpnkit
```

## Run

```sh
wsl.exe -d wsl-vpnkit service wsl-vpnkit start
```

Add the command to your `.profile` or `.bashrc` to start `wsl-vpnkit` when you open your WSL terminal.

### Notes

* Services on the WSL 2 VM are accessible from the Windows host using `localhost`. (ref [`localhostForwarding`](https://docs.microsoft.com/en-us/windows/wsl/wsl-config#wsl-2-settings))
* Services on the Windows host are accessible from WSL 2 using the IP from `VPNKIT_HOST_IP` (`192.168.67.2`).

## Troubleshooting

### Configure VS Code Remote WSL Extension

If VS Code takes a long time to open your folder in WSL, [enable the setting "Connect Through Localhost"](https://github.com/microsoft/vscode-docs/blob/main/remote-release-notes/v1_54.md#fix-for-wsl-2-connection-issues-when-behind-a-proxy).

### Try shutting down WSL 2 VM to reset

```ps
wsl --shutdown
Stop-Process -Name wsl-vpnkit
```

## Uninstall

To uninstall, simply unregister the `wsl-vpnkit` distro.

```ps
wsl --unregister wsl-vpnkit
Remove-Item -Recurse $env:USERPROFILE\wsl-vpnkit
```
