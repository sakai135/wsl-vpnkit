FROM alpine:3.14.2 AS vpnkit
RUN apk add --no-cache p7zip && \
    apk list --installed
WORKDIR /files
RUN echo "8f36a5b306442d03a87bb80a492558c81902fdabe497af44a39ca07c161c60a5  Docker%20Desktop%20Installer.exe" > sha256sums && \
    wget https://desktop.docker.com/win/stable/amd64/67351/Docker%20Desktop%20Installer.exe  && \
    sha256sum -c sha256sums && \
    7z e Docker%20Desktop%20Installer.exe resources/vpnkit.exe resources/wsl/docker-for-wsl.iso && \
    7z e docker-for-wsl.iso containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd && \
    chmod +x vpnkit-tap-vsockd && \
    rm Docker%20Desktop%20Installer.exe docker-for-wsl.iso sha256sums && \
    wget https://raw.githubusercontent.com/moby/vpnkit/v0.5.0/LICENSE

FROM golang:1.17.1-alpine3.14 AS npiperelay
RUN apk add --no-cache git && \
    apk list --installed
WORKDIR /app
RUN mkdir /files && \
    git -c advice.detachedHead=false clone --branch v0.1.0 --depth 1 https://github.com/jstarks/npiperelay.git . && \
    [[ "4997d3bf5f2e512608b39b51f37412206758051b" = "$(git rev-parse --verify HEAD)" ]] && \
    GOOS=windows go build -ldflags '-s -w' -o /files/npiperelay.exe . && \
    cp ./LICENSE /files/

FROM alpine:3.14.2
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
