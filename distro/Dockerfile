FROM alpine:3.14.2 AS files
WORKDIR /files
RUN apk add --no-cache p7zip
RUN wget https://desktop.docker.com/win/stable/amd64/67351/Docker%20Desktop%20Installer.exe  && \
    7z e Docker%20Desktop%20Installer.exe resources/vpnkit.exe resources/wsl/docker-for-wsl.iso && \
    7z e docker-for-wsl.iso containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd && \
    chmod +x vpnkit-tap-vsockd && \
    rm Docker%20Desktop%20Installer.exe docker-for-wsl.iso
RUN wget https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip && \
    7z e npiperelay_windows_amd64.zip npiperelay.exe && \
    rm npiperelay_windows_amd64.zip

FROM alpine:3.14.2
WORKDIR /app
RUN apk add --no-cache socat openrc iptables
COPY --from=files /files/npiperelay.exe /files/vpnkit.exe /files/
COPY --from=files /files/vpnkit-tap-vsockd /usr/sbin/
COPY ./wsl-vpnkit /usr/sbin/
COPY ./distro/wsl-vpnkit.service /etc/init.d/wsl-vpnkit
COPY ./distro/startup.sh /etc/profile.d/
