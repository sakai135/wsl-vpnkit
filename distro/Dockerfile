FROM alpine:3.14.2 AS vpnkit
WORKDIR /files
RUN apk add --no-cache p7zip
COPY ./distro/sha256sums ./
RUN wget https://desktop.docker.com/win/stable/amd64/67351/Docker%20Desktop%20Installer.exe  && \
    sha256sum -c sha256sums && \
    7z e Docker%20Desktop%20Installer.exe resources/vpnkit.exe resources/wsl/docker-for-wsl.iso && \
    7z e docker-for-wsl.iso containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd && \
    chmod +x vpnkit-tap-vsockd && \
    rm Docker%20Desktop%20Installer.exe docker-for-wsl.iso

FROM golang:1.17.1-alpine3.14 AS npiperelay
WORKDIR /files
ENV GOOS=windows
RUN go mod init local/build && \
    go get -d -v github.com/jstarks/npiperelay@v0.1.0 && \
    GOOS=windows go build -o ./npiperelay.exe github.com/jstarks/npiperelay

FROM alpine:3.14.2
ARG REF=0
WORKDIR /app
RUN apk add --no-cache socat openrc iptables && \
    mkdir /files && \
    echo "$REF" > /files/ref
COPY --from=npiperelay /files/npiperelay.exe /files/
COPY --from=vpnkit /files/vpnkit.exe /files/
COPY --from=vpnkit /files/vpnkit-tap-vsockd /usr/sbin/
COPY ./wsl-vpnkit /usr/sbin/
COPY ./distro/wsl-vpnkit.service /etc/init.d/wsl-vpnkit
COPY ./distro/startup.sh /etc/profile.d/
