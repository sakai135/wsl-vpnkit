#! /mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0//powershell.exe

& 'C:\Program Files\Docker\Docker\resources\vpnkit.exe' --ethernet \\.\pipe\wsl-vpnkit --http "$env:APPDATA\Docker\http_proxy.json" --gateway-forwards "$env:APPDATA\Docker\gateway_forwards.json" --listen-backlog 32 --gateway-ip 192.168.67.1 --host-ip 192.168.67.2 --lowest-ip 192.168.67.3 --highest-ip 192.168.67.14
