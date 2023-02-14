FROM docker.io/library/golang:1.20.0-alpine as build
WORKDIR /app
RUN apk add git make
RUN git clone https://github.com/containers/gvisor-tap-vsock.git --single-branch /app
RUN make && make cross
RUN find ./bin -type f -exec sha256sum {} \;

FROM docker.io/library/fedora:37
RUN dnf upgrade -y
RUN dnf install -y dhcp-client iptables-legacy bind-utils wget && \
    dnf clean all
WORKDIR /app
COPY --from=build /app/bin/vm /usr/bin/wsl-vm
COPY --from=build /app/bin/gvproxy-windows.exe ./wsl-gvproxy.exe
COPY ./distro/wsl.conf /etc/wsl.conf
COPY ./wsl-vpnkit /usr/bin/
