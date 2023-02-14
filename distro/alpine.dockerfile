FROM docker.io/library/golang:1.20.0-alpine as build
WORKDIR /app
RUN apk add git make
RUN git clone https://github.com/containers/gvisor-tap-vsock.git --single-branch /app
RUN make && make cross
RUN find ./bin -type f -exec sha256sum {} \;

FROM docker.io/library/alpine:3.17.2
RUN apk update && \
    apk upgrade && \
    apk add iptables && \
    apk list --installed && \
    rm -rf /var/cache/apk/*
WORKDIR /app
COPY --from=build /app/bin/vm /usr/bin/wsl-vm
COPY --from=build /app/bin/gvproxy-windows.exe ./wsl-gvproxy.exe
COPY ./distro/wsl.conf /etc/wsl.conf
COPY ./wsl-vpnkit /usr/bin/
ARG REF=https://example.com/
ARG VERSION=v0.0.0
RUN echo "$REF" > ./ref && \
    echo "$VERSION" > ./version
