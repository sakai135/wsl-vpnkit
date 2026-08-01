#!/bin/sh

set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
image="wsl-vpnkit-test:$$"
network="wsl-vpnkit-test-net-$$"

cleanup () {
    docker network rm "$network" >/dev/null 2>&1 || :
    docker image rm "$image" >/dev/null 2>&1 || :
}
trap cleanup EXIT INT TERM

docker build --quiet -f "$root_dir/tests/docker/Dockerfile" -t "$image" "$root_dir" >/dev/null
docker network create --driver bridge "$network" >/dev/null
docker run --rm \
    --cap-drop=ALL \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    --device=/dev/net/tun:/dev/net/tun \
    --security-opt=no-new-privileges:true \
    --read-only \
    --tmpfs=/run:rw,nosuid,nodev \
    --tmpfs=/tmp:rw,nosuid,nodev \
    --network "$network" \
    --env DEBUG="${DEBUG:-}" \
    "$image"
