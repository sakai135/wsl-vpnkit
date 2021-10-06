FROM alpine:3.14.2 AS vpnkit
WORKDIR /files
COPY ./distro/vpnkit/sha256sums ./
RUN apk add --no-cache p7zip && \
    wget https://desktop.docker.com/win/stable/amd64/67351/Docker%20Desktop%20Installer.exe  && \
    sha256sum -c sha256sums && \
    7z e Docker%20Desktop%20Installer.exe resources/vpnkit.exe resources/wsl/docker-for-wsl.iso && \
    7z e docker-for-wsl.iso containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd && \
    chmod +x vpnkit-tap-vsockd && \
    rm Docker%20Desktop%20Installer.exe docker-for-wsl.iso sha256sums && \
    wget https://raw.githubusercontent.com/moby/vpnkit/v0.5.0/LICENSE

FROM golang:1.17.1-alpine3.14 AS npiperelay
WORKDIR /files
COPY ./distro/npiperelay/go.mod ./distro/npiperelay/go.sum ./
RUN go mod download -x && \
    GOOS=windows go build -o ./npiperelay.exe github.com/jstarks/npiperelay && \
    rm go.mod go.sum && \
    cp /go/pkg/mod/github.com/jstarks/npiperelay@v0.1.0/LICENSE ./

FROM alpine:3.14.2
ARG REF=https://example.com/
ARG VERSION=v0.0.0
WORKDIR /app
COPY --from=npiperelay /files /files/npiperelay
COPY --from=vpnkit /files /files/vpnkit
COPY ./distro/wsl-vpnkit.service ./distro/startup.sh ./wsl-vpnkit ./LICENSE ./
RUN apk add --no-cache socat openrc iptables && \
    apk list --installed && \
    echo "$REF" > /app/ref && \
    echo "$VERSION" > /app/version && \
    ln -s /files/vpnkit/vpnkit-tap-vsockd /app/wsl-vpnkit /usr/sbin/ && \
    ln -s /app/wsl-vpnkit.service /etc/init.d/wsl-vpnkit && \
    ln -s /app/startup.sh /etc/profile.d/
