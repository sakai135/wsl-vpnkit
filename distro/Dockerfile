FROM docker.io/library/golang:1.20.0-alpine as build
WORKDIR /app
RUN apk add git make
RUN git clone https://github.com/sakai135/gvisor-tap-vsock.git --branch wsl --single-branch /app
RUN make && make cross
RUN find ./bin -type f -exec sha256sum {} \;

FROM docker.io/library/alpine:3.17.2
RUN apk add --no-cache iptables && \
    apk list --installed
WORKDIR /app
COPY --from=build /app/bin/vm /usr/bin/wsl-vm
COPY --from=build /app/bin/gvproxy-windows.exe ./wsl-gvproxy.exe
COPY ./distro/udhcpc.conf /etc/udhcpc/udhcpc.conf
COPY ./distro/wsl.conf /etc/wsl.conf
COPY ./wsl-vpnkit /usr/bin/
ARG REF=https://example.com/
ARG VERSION=v0.0.0
RUN echo "$REF" > ./ref && \
    echo "$VERSION" > ./version
