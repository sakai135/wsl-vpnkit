FROM --platform=$BUILDPLATFORM docker.io/library/golang:1.26.5 AS gvisor-tap-vsock-arm64
WORKDIR /app
RUN git clone --depth 1 --branch v0.8.9 https://github.com/containers/gvisor-tap-vsock.git . && \
    GOARCH=arm64 make vm && \
    wget https://github.com/containers/gvisor-tap-vsock/releases/download/v0.8.9/gvproxy-windows-arm64.exe && \
    mv ./gvproxy-windows-arm64.exe ./bin/gvproxy-windows.exe && \
    chmod +x ./bin/gvproxy-windows.exe ./bin/gvforwarder

FROM --platform=$BUILDPLATFORM docker.io/library/alpine:3.24.1 AS gvisor-tap-vsock
WORKDIR /app/bin/amd64
RUN wget https://github.com/containers/gvisor-tap-vsock/releases/download/v0.8.9/gvproxy-windows.exe && \
    wget https://github.com/containers/gvisor-tap-vsock/releases/download/v0.8.9/gvforwarder && \
    chmod +x ./gvproxy-windows.exe ./gvforwarder
WORKDIR /app/bin/arm64
COPY --from=gvisor-tap-vsock-arm64 /app/bin/gvproxy-windows.exe ./
COPY --from=gvisor-tap-vsock-arm64 /app/bin/gvforwarder ./
WORKDIR /app
COPY ./distro/checksums ./
RUN sha256sum -c checksums

FROM docker.io/library/ubuntu:26.04
ARG TARGETARCH
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y iproute2 iptables iputils-ping dnsutils wget jq && \
    apt-get clean
WORKDIR /app
COPY --from=gvisor-tap-vsock /app/bin/${TARGETARCH}/gvforwarder ./wsl-vm
COPY --from=gvisor-tap-vsock /app/bin/${TARGETARCH}/gvproxy-windows.exe ./wsl-gvproxy.exe
COPY ./wsl-vpnkit ./wsl-vpnkit.service ./
COPY ./distro/wsl.conf ./distro/wsl-distribution.conf ./distro/wsl-oobe.sh /etc/
ARG REF=https://example.com/
ARG VERSION=v0.0.0
RUN find ./ -type f -exec sha256sum {} \; && \
    ln -s /app/wsl-vpnkit /app/wsl-vm /app/wsl-gvproxy.exe /usr/local/bin/ && \
    echo "$REF" > ./ref && \
    echo "$VERSION" > ./version && \
    echo "$TARGETARCH" > ./arch
