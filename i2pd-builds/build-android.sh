#!/bin/bash
set -xe
# I was kind of looking for a combo of versions that would work
# - the ones below exited for reasons I don't remember right
# now - but be aware that you can't just use latest tooling and
# expect it to work. 
# 21.4.7075529
# 22.0.7026061
# 23.0.7599858
# 24.0.8215888
export NDK_VERSION=23.0.7599858
export ANDROID_SDK_ROOT=/opt/android-sdk
export ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk/$NDK_VERSION
export ANDROID_HOME=$ANDROID_SDK_ROOT/ndk/$NDK_VERSION
export BUILD_DIR=$(mktemp -d)
export WGET_DIR="$(mktemp -d)"

cd $BUILD_DIR

apt update
apt install -y g++ rename default-jdk gradle wget git cmake file bzip2
(cd "$WGET_DIR" && wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip)
unzip $WGET_DIR/commandlinetools-linux-*_latest.zip
yes | ./cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk "build-tools;31.0.0" "cmake;3.18.1" "ndk;$NDK_VERSION"

git clone --recurse-submodules https://github.com/PurpleI2P/i2pd-android.git

cd i2pd-android

cd binary/jni
./build_boost.sh
./build_openssl.sh
./build_miniupnpc.sh
$ANDROID_NDK_HOME/ndk-build -j $(nproc --all) NDK_MODULE_PATH=$PWD
cd ../libs
mkdir -p /out/android_{arm64,arm,i386,amd64}
mv arm64-v8a/i2pd /out/android_arm64/i2pd
mv armeabi-v7a/i2pd /out/android_arm/i2pd
mv x86/i2pd /out/android_i386/i2pd
mv x86_64/i2pd /out/android_amd64/i2pd

# echo "$ pwd" > build_info.txt
# pwd >> build_info.txt
# echo "$ uname -a" > build_info.txt
# uname -a >> build_info.txt
# echo "$ cat /etc/os-release" > build_info.txt
# cat /etc/os-release >> build_info.txt
# echo "$ cmake .. -L" >> build_info.txt
# cmake .. -L >> build_info.txt