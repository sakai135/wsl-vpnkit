# FROM docker.io/library/golang:1.20.0-alpine as gvisor-tap-vsock
# WORKDIR /app
# RUN apk add git make
# RUN git clone https://github.com/containers/gvisor-tap-vsock.git --single-branch /app
# RUN make && make cross
# RUN find ./bin -type f -exec sha256sum {} \;

FROM docker.io/library/golang:1.20.0-alpine as gvisor-tap-vsock
WORKDIR /app
RUN apk add git make
RUN git clone https://github.com/sakai135/gvisor-tap-vsock.git --single-branch --branch fix-stdio /app
RUN make && make cross
RUN find ./bin -type f -exec sha256sum {} \;

FROM docker.io/library/fedora:37
RUN dnf upgrade -y && \
    dnf install -y iproute iptables-legacy iputils bind-utils wget && \
    dnf clean all
WORKDIR /app
COPY --from=gvisor-tap-vsock /app/bin/vm ./wsl-vm
COPY --from=gvisor-tap-vsock /app/bin/gvproxy-windows.exe ./wsl-gvproxy.exe
COPY ./wsl-vpnkit ./wsl-vpnkit.service ./
COPY ./distro/wsl.conf /etc/wsl.conf
RUN ln -s /app/wsl-vpnkit /usr/bin/
