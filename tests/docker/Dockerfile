FROM docker.io/library/golang:1.26.5 AS gvisor-tap-vsock
WORKDIR /app
RUN git clone --depth 1 --branch v0.8.9 https://github.com/containers/gvisor-tap-vsock.git . && \
    CGO_ENABLED=0 make gvproxy vm && \
    chmod +x ./bin/gvproxy ./bin/gvforwarder

FROM docker.io/library/alpine:3.24.1
RUN apk update && \
    apk upgrade && \
    apk add iproute2 iptables jq && \
    rm -rf /var/cache/apk/*
WORKDIR /app
COPY --from=gvisor-tap-vsock /app/bin/gvforwarder ./wsl-vm
COPY --from=gvisor-tap-vsock /app/bin/gvproxy ./wsl-gvproxy.exe
COPY ./wsl-vpnkit ./wsl-vpnkit.service ./
COPY tests/docker/mock-vm tests/docker/test.sh /tests/
RUN ln -s /app/wsl-vpnkit /app/wsl-vm /app/wsl-gvproxy.exe /usr/local/bin/

ENTRYPOINT ["/tests/test.sh"]
