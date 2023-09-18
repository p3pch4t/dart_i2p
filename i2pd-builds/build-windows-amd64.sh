#!/bin/bash

# NOTE: As for now it doesn't really work.
# No idea why, I won't dig deep into it.

BOOST_BRANCH="boost-1.83.0"

set -xe
apt update
apt-get install -y g++-mingw-w64-x86-64 git cmake build-essential
update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

mkdir -p ~/dev
cd ~/dev

mkdir -p ~/dev/boost_1_83_0/
cd ~/dev/boost_1_83_0/
git clone https://github.com/boostorg/boost . --recursive -b "$BOOST_BRANCH" 
echo "using gcc : mingw : x86_64-w64-mingw32-g++ ;" > ~/user-config.jam

./b2 toolset=gcc-mingw target-os=windows variant=release link=static runtime-link=static address-model=64 \
  --build-type=minimal --with-filesystem --with-program_options --with-date_time \
  --stagedir=stage-mingw-64
cd ..

git clone https://github.com/openssl/openssl
cd openssl
git checkout OpenSSL_1_0_2g
./Configure mingw64 no-rc2 no-rc4 no-rc5 no-idea no-bf no-cast no-whirlpool no-md2 no-md4 no-ripemd no-mdc2 \
  no-camellia no-seed no-comp no-krb5 no-gmp no-rfc3779 no-ec2m no-ssl2 no-jpake no-srp no-sctp no-srtp \
  --prefix=~/dev/stage --cross-compile-prefix=x86_64-w64-mingw32-
make depend
make
make install
cd ..

git clone https://github.com/madler/zlib
cd zlib
git checkout v1.2.8
CC=x86_64-w64-mingw32-gcc CFLAGS=-O3 ./configure --static --64 --prefix=~/dev/stage
make
make install
cd ..

cat > ~/dev/toolchain-mingw.cmake <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
EOF

cd ~/dev
mkdir i2pd-mingw-64-build
cd i2pd-mingw-64-build
BOOST_ROOT=~/dev/boost_1_83_0 cmake -G 'Unix Makefiles' /build/build -DBUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=~/dev/toolchain-mingw.cmake -DWITH_AESNI=ON -DWITH_UPNP=OFF -DWITH_STATIC=ON \
  -DWITH_HARDENING=ON -DCMAKE_INSTALL_PREFIX:PATH=~/dev/i2pd-mingw-64-static \
  -DZLIB_ROOT=~/dev/stage -DBOOST_LIBRARYDIR:PATH=~/dev/boost_1_83_0
_0/stage-mingw-64/lib \
  -DOPENSSL_ROOT_DIR:PATH=~/dev/stage
make
x86_64-w64-mingw32-strip i2pd.exe