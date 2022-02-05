FROM golang:1.17.6-alpine as build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN GOOS=windows go build -ldflags '-s -w -H=windowsgui' -o bin/wsl-gvproxy.exe ./cmd/gvproxy && \
    GOOS=linux CGO_ENABLED=0 go build -ldflags '-s -w' -o bin/wsl-vm ./cmd/vm

FROM golang:1.17.6-alpine as licenses
RUN apk add --no-cache git && \
    apk list --installed && \
    go install github.com/google/go-licenses@v1.0.0
WORKDIR /app
COPY . .
RUN go-licenses save ./cmd/gvproxy --save_path ./licenses/gvproxy && \
    go-licenses save ./cmd/vm --save_path ./licenses/vm

FROM alpine:3.15.0
RUN apk add --no-cache openrc iptables && \
    apk list --installed
ARG REF=https://example.com/
ARG VERSION=v0.0.0
WORKDIR /app
COPY --from=build /app/bin /files/
COPY --from=licenses /app/licenses/gvproxy /app/licenses/vm /licenses/
COPY ./distro/scripts/ ./wsl-vpnkit ./LICENSE ./
RUN echo "$REF" > /app/ref && \
    echo "$VERSION" > /app/version && \
    find /files -type f -exec sha256sum {} \; && \
    ln -s /files/wsl-vm /app/wsl-vpnkit /usr/sbin/ && \
    ln -s /app/wsl-vpnkit.service /etc/init.d/wsl-vpnkit && \
    ln -s /app/startup.sh /etc/profile.d/
