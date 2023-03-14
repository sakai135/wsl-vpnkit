# FROM docker.io/library/alpine:3.17.2 as gvisor-tap-vsock
# WORKDIR /app/bin
# RUN wget -O gvproxy-windows.exe https://github.com/containers/gvisor-tap-vsock/releases/download/v0.6.0/gvproxy-windows.exe && \
#     wget -O vm https://github.com/containers/gvisor-tap-vsock/releases/download/v0.6.0/vm && \
#     chmod +x ./gvproxy-windows.exe ./vm
# RUN find . -type f -exec sha256sum {} \;

FROM docker.io/library/golang:1.20.0-alpine as gvisor-tap-vsock
WORKDIR /app
RUN apk add git make
RUN git clone https://github.com/sakai135/gvisor-tap-vsock.git --single-branch --branch fix-stdio /app
RUN make && make cross
RUN find ./bin -type f -exec sha256sum {} \;

FROM docker.io/library/alpine:3.17.2
RUN apk update && \
    apk upgrade && \
    apk add iproute2 iptables && \
    apk list --installed && \
    rm -rf /var/cache/apk/*
WORKDIR /app
COPY --from=gvisor-tap-vsock /app/bin/vm ./wsl-vm
COPY --from=gvisor-tap-vsock /app/bin/gvproxy-windows.exe ./wsl-gvproxy.exe
COPY ./wsl-vpnkit ./wsl-vpnkit.service ./
COPY ./distro/wsl.conf /etc/wsl.conf
ARG REF=https://example.com/
ARG VERSION=v0.0.0
RUN find ./ -type f -exec sha256sum {} \; && \
    ln -s /app/wsl-vpnkit /usr/bin/ && \
    echo "$REF" > ./ref && \
    echo "$VERSION" > ./version
