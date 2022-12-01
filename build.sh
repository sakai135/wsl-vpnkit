#!/bin/bash -xe

# run from repo root
# ./build.sh

: "${DOCKER:=docker}"   # docker/podman command  (default: docker)
DUMP=wsl-vpnkit.tar.gz  # exported rootfs file
TAG_NAME=wslvpnkit      # build tag

# build
build_args=()
[ -z "${http_proxy}" ] || build_args+=( --build-arg http_proxy="${http_proxy}" )
[ -z "${https_proxy}" ] || build_args+=( --build-arg https_proxy="${https_proxy}" )
[ -z "${no_proxy}" ] || build_args+=( --build-arg no_proxy="${no_proxy}" )
${DOCKER} build --network host "${build_args[@]}" --tag ${TAG_NAME} --file ./distro/Dockerfile .
CONTAINER_ID=$(${DOCKER} create ${TAG_NAME})
${DOCKER} export "${CONTAINER_ID}" | gzip > ${DUMP}
${DOCKER} container rm "${CONTAINER_ID}"
ls -la ${DUMP}
