#!/bin/bash -xe

# run from repo root
# ./build.sh

: "${DOCKER:=docker}"   # docker/podman command  (default: docker)
DUMP=wsl-vpnkit.wsl  # exported rootfs file
TAG_NAME=wslvpnkit      # build tag
BASE_DISTRO=$1
UPDATE_CHECKSUMS=$2

build_args=()
[ -z "${http_proxy}" ] || build_args+=( --build-arg http_proxy="${http_proxy}" )
[ -z "${https_proxy}" ] || build_args+=( --build-arg https_proxy="${https_proxy}" )
[ -z "${no_proxy}" ] || build_args+=( --build-arg no_proxy="${no_proxy}" )

if [ "${UPDATE_CHECKSUMS}" = "update-checksums" ]; then
  CHECKSUM_TAG="${TAG_NAME}-checksum"

  ${DOCKER} build --network host "${build_args[@]}" --target gvisor-tap-vsock-arm64 \
    --tag "${CHECKSUM_TAG}" --file "./distro/${BASE_DISTRO}.dockerfile" .
  GVFORWARDER_CHECKSUM=$(${DOCKER} run --rm "${CHECKSUM_TAG}" sha256sum /app/bin/gvforwarder | cut -d ' ' -f1)
  [ "$(grep -Ec '^[[:xdigit:]]+[[:space:]]+\./bin/arm64/gvforwarder$' distro/checksums)" -eq 1 ]
  sed -i -E "s|^[[:xdigit:]]+[[:space:]]+\\./bin/arm64/gvforwarder\$|${GVFORWARDER_CHECKSUM}  ./bin/arm64/gvforwarder|" distro/checksums
fi

# build
${DOCKER} build --network host "${build_args[@]}" --tag "${TAG_NAME}" --file "./distro/${BASE_DISTRO}.dockerfile" .
CONTAINER_ID=$(${DOCKER} create "${TAG_NAME}")
${DOCKER} export "${CONTAINER_ID}" | gzip > "${DUMP}"
${DOCKER} container rm "${CONTAINER_ID}"
ls -la "${DUMP}"
