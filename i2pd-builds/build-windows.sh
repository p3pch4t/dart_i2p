#!/bin/bash

set -xe

cd "$(dirname $0)"
OUTDIR="$(pwd)/out"
mkdir -p "$OUTDIR" || true

for MINGW_ARCH in 32 64;
do
    BUILDDIR="$(mktemp -d)"
    cd "$BUILDDIR"

    git clone https://github.com/PurpleI2P/i2pd.git -b 2.49.0
    cd i2pd
    PATH=/mingw$MINGW_ARCH/bin:/usr/bin make -j$(nproc --all)
    PATH=/mingw$MINGW_ARCH/bin:/usr/bin bash -c 'strip i2pd.exe'
    mkdir -p "$OUTDIR/windows/$MINGW_ARCH" || true
    mv i2pd.exe "$OUTDIR/windows/$MINGW_ARCH/"
    cd "$BUILDDIR"
    git clone --recursive https://github.com/purplei2p/i2pd-tools
    cd i2pd-tools
    PATH=/mingw$MINGW_ARCH/bin:/usr/bin make -j$(nproc --all)
    PATH=/mingw$MINGW_ARCH/bin:/usr/bin bash -c 'strip *.exe'
    mv *.exe "$OUTDIR/windows/$MINGW_ARCH/"
done

cd "$OUTDIR/windows"
find * -type f -name '*.exe' | parallel -v '$DOCKER_PREFIX upx --best {}'
