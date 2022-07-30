FROM alpine:3.16.1 AS vpnkit
WORKDIR /files
RUN wget https://github.com/sakai135/vpnkit/releases/download/v0.5.0-20211026/vpnkit-tap-vsockd && \
    wget https://github.com/sakai135/vpnkit/releases/download/v0.5.0-20211026/vpnkit.exe && \
    wget https://raw.githubusercontent.com/sakai135/vpnkit/v0.5.0-20211026/LICENSE && \
    chmod +x vpnkit-tap-vsockd && \
    find . -type f -exec sha256sum {} \;

FROM alpine:3.16.1 AS npiperelay
RUN apk add --no-cache p7zip && \
    apk list --installed
WORKDIR /files
RUN wget https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip && \
    7z e npiperelay_windows_amd64.zip npiperelay.exe LICENSE && \
    rm npiperelay_windows_amd64.zip && \
    find . -type f -exec sha256sum {} \;

FROM alpine:3.16.1
RUN apk add --no-cache socat openrc iptables && \
    apk list --installed
ARG REF=https://example.com/
ARG VERSION=v0.0.0
WORKDIR /app
COPY --from=npiperelay /files /files/npiperelay
COPY --from=vpnkit /files /files/vpnkit
COPY ./distro/scripts/ ./wsl-vpnkit ./LICENSE ./
RUN echo "$REF" > /app/ref && \
    echo "$VERSION" > /app/version && \
    ln -s /files/vpnkit/vpnkit-tap-vsockd /app/wsl-vpnkit /usr/sbin/ && \
    ln -s /app/wsl-vpnkit.service /etc/init.d/wsl-vpnkit && \
    ln -s /app/startup.sh /etc/profile.d/
