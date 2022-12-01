#! /bin/bash -xe

# run from repo root
# ./build.sh

USERPROFILE=$(wslvar USERPROFILE)
DUMP=wsl-vpnkit.tar.gz
TAG_NAME=wslvpnkit

# build
build_args=()
[ -z "${http_proxy}" ] || build_args+=( --build-arg http_proxy="${http_proxy}" )
[ -z "${https_proxy}" ] || build_args+=( --build-arg https_proxy="${https_proxy}" )
[ -z "${no_proxy}" ] || build_args+=( --build-arg no_proxy="${no_proxy}" )
docker build --network host "${build_args[@]}" --tag ${TAG_NAME} --file ./distro/Dockerfile .
CONTAINER_ID=$(docker create ${TAG_NAME})
docker export "${CONTAINER_ID}" | gzip > ${DUMP}
docker container rm "${CONTAINER_ID}"
ls -la ${DUMP}

# reinstall
wsl.exe --unregister wsl-vpnkit || :
wsl.exe --import wsl-vpnkit --version 2 "${USERPROFILE}\\wsl-vpnkit" ${DUMP}
rm ${DUMP}
