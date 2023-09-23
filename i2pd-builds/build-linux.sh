#!/bin/bash

ARCH=$1

if [[ "x$ARCH" == "x" ]];
then
    echo "Usage: ./build-linux.sh arch";
    echp "p.s. don't use this script directly."
    exit 1;
fi
set -xe


set -xe
apt update
apt install -y cmake binutils build-essential debhelper libboost-date-time-dev libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libssl-dev zlib1g-dev libminiupnpc-dev git

git clone --recursive https://github.com/PurpleI2P/i2pd.git i2pd-src -b 2.49.0
mkdir -p i2pd-src/build/build-linux-$ARCH
cd i2pd-src/build/build-linux-$ARCH
cmake .. -DWITH_STATIC=ON

echo "$ pwd" > build_info.txt
pwd >> build_info.txt
echo "$ uname -a" > build_info.txt
uname -a >> build_info.txt
echo "$ cat /etc/os-release" > build_info.txt
cat /etc/os-release >> build_info.txt
echo "$ cmake .. -L" >> build_info.txt
cmake .. -L >> build_info.txt

make -j$(nproc --all)
mkdir -p /out/linux_"$ARCH"
mv i2pd /out/linux_"$ARCH"/i2pd
cd $HOME
git clone --recursive https://github.com/purplei2p/i2pd-tools
cd i2pd-tools
sed 's/LDFLAGS = /LDFLAGS = -static/g' -i Makefile
make -j $(nproc --all)
mv b33address famtool i2pbase64 keygen keyinfo offlinekeys regaddr regaddr_3ld regaddralias routerinfo vain verifyhost x25519 /out/linux_"$ARCH"
strip /out/linux_"$ARCH"/*