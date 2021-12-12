FROM alpine:3.15.0 AS vpnkit
RUN apk add --no-cache p7zip && \
    apk list --installed
WORKDIR /files
RUN wget https://github.com/sakai135/vpnkit/releases/download/v0.5.0-20211026/vpnkit-tap-vsockd && \
    wget https://github.com/sakai135/vpnkit/releases/download/v0.5.0-20211026/vpnkit.exe && \
    wget https://raw.githubusercontent.com/sakai135/vpnkit/v0.5.0-20211026/LICENSE && \
    chmod +x vpnkit-tap-vsockd && \
    find . -type f -exec sha256sum {} \;

FROM golang:1.17.4-alpine3.15 AS npiperelay
RUN apk add --no-cache git && \
    apk list --installed
WORKDIR /app
RUN mkdir /files && \
    git -c advice.detachedHead=false clone --branch v0.1.0 --depth 1 https://github.com/jstarks/npiperelay.git . && \
    [[ "4997d3bf5f2e512608b39b51f37412206758051b" = "$(git rev-parse --verify HEAD)" ]] && \
    GOOS=windows go build -ldflags '-s -w' -o /files/npiperelay.exe . && \
    cp ./LICENSE /files/ && \
    cd /files && \
    find . -type f -exec sha256sum {} \;

FROM alpine:3.15.0
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
