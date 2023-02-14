FROM docker.io/library/golang:1.20.0-alpine as build
WORKDIR /app
RUN apk add git make
RUN git clone https://github.com/containers/gvisor-tap-vsock.git --single-branch /app
RUN make && make cross
RUN find ./bin -type f -exec sha256sum {} \;

FROM docker.io/library/ubuntu:22.04
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y isc-dhcp-client iproute2 iptables iputils-ping dnsutils wget && \
    apt-get clean
WORKDIR /app
COPY --from=build /app/bin/vm /usr/bin/wsl-vm
COPY --from=build /app/bin/gvproxy-windows.exe ./wsl-gvproxy.exe
COPY ./distro/wsl.conf /etc/wsl.conf
COPY ./wsl-vpnkit /usr/bin/
