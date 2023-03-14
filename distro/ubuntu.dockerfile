FROM docker.io/library/alpine:3.17.2 as gvisor-tap-vsock
WORKDIR /app/bin
RUN wget https://github.com/containers/gvisor-tap-vsock/releases/download/v0.6.1/gvproxy-windows.exe && \
    wget https://github.com/containers/gvisor-tap-vsock/releases/download/v0.6.1/vm && \
    chmod +x ./gvproxy-windows.exe ./vm
RUN find . -type f -exec sha256sum {} \;

FROM docker.io/library/ubuntu:22.04
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y iproute2 iptables iputils-ping dnsutils wget && \
    apt-get clean
WORKDIR /app
COPY --from=gvisor-tap-vsock /app/bin/vm ./wsl-vm
COPY --from=gvisor-tap-vsock /app/bin/gvproxy-windows.exe ./wsl-gvproxy.exe
COPY ./wsl-vpnkit ./wsl-vpnkit.service ./
COPY ./distro/wsl.conf /etc/wsl.conf
RUN ln -s /app/wsl-vpnkit /usr/bin/
