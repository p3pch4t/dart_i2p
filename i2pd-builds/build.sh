#!/bin/bash
# Usage: DOCKER_PREFIX=sudo ./build.sh
# or
# Usage: sudo ./build.sh

BUILD_IMAGE="debian:stable"
BUILD_IMAGE_ANDROID="debian:stable"

docker run --rm -it $BUILD_IMAGE /bin/true
if ! $DOCKER_PREFIX docker run --rm -it $BUILD_IMAGE /bin/true;
then
    echo "Running docker failed, setting DOCKER_PREFIX=sudo"
    DOCKER_PREFIX="sudo"
fi

set -xe
cd $(dirname $0)

if [[ -d "out" ]];
then
    $DOCKER_PREFIX rm -rf out/* || true
fi

mkdir out || true
cd out
OUTDIR=$(pwd)
cd ..

BPATH=$(pwd)
$DOCKER_PREFIX docker system prune -af # yeah. it's needed because for some reason *on my system* linux/amd64 is linux/i386...
$DOCKER_PREFIX docker run --platform linux/amd64 -v $OUTDIR:/out -v $BPATH/build-linux.sh:/bin/build.sh -w /build --rm -it $BUILD_IMAGE bash /bin/build.sh amd64
$DOCKER_PREFIX docker run --platform linux/arm64 -v $OUTDIR:/out -v $BPATH/build-linux.sh:/bin/build.sh -w /build --rm -it $BUILD_IMAGE bash /bin/build.sh arm64
$DOCKER_PREFIX docker run --platform linux/arm -v $OUTDIR:/out -v $BPATH/build-linux.sh:/bin/build.sh -w /build --rm -it $BUILD_IMAGE bash /bin/build.sh arm
$DOCKER_PREFIX docker run --platform linux/i386 -v $OUTDIR:/out -v $BPATH/build-linux.sh:/bin/build.sh -w /build --rm -it $BUILD_IMAGE bash /bin/build.sh i386
$DOCKER_PREFIX docker system prune -af
# TODO: windows
# $DOCKER_PREFIX docker run --platform linux/amd64 -v $OUTDIR:/out -v $BPATH/build-windows-arm64.sh:/bin/build.sh -w /build --rm -it $BUILD_IMAGE /bin/build.sh
$DOCKER_PREFIX docker run --platform linux/amd64 -v $OUTDIR:/out -v $BPATH/build-android.sh:/bin/build.sh -w /build --rm -it $BUILD_IMAGE_ANDROID bash /bin/build.sh

# $DOCKER_PREFIX docker run --platform linux/amd64 -v $OUTDIR:/out -v $BPATH/postprocess.sh:/bin/build.sh -w /build --rm -it $BUILD_IMAGE bash /bin/build.sh

cd $OUTDIR
find * -type f | parallel -v '$DOCKER_PREFIX upx --best {}'