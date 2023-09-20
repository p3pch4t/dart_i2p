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
# i2pd-android
apt install -y g++ rename default-jdk gradle wget git cmake file bzip2
# i2pd-tools
apt install -y cmake binutils build-essential debhelper libboost-date-time-dev libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libssl-dev zlib1g-dev libminiupnpc-dev git

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
mkdir -p /out/android/{arm64-v8a,armeabi-v7a,x86,x86_64}
cp -a arm64-v8a/i2pd /out/linux_arm64/{b33address,famtool,i2pbase64,keygen,keyinfo,offlinekeys,regaddr,regaddr_3ld,regaddralias,routerinfo,vain,verifyhost,x25519} /out/android/arm64-v8a/
cp -a armeabi-v7a/i2pd /out/linux_arm/{b33address,famtool,i2pbase64,keygen,keyinfo,offlinekeys,regaddr,regaddr_3ld,regaddralias,routerinfo,vain,verifyhost,x25519} /out/android/armeabi-v7a/
cp -a x86/i2pd /out/linux_i386/{b33address,famtool,i2pbase64,keygen,keyinfo,offlinekeys,regaddr,regaddr_3ld,regaddralias,routerinfo,vain,verifyhost,x25519} /out/android/x86/
cp -a x86_64/i2pd /out/linux_amd64/{b33address,famtool,i2pbase64,keygen,keyinfo,offlinekeys,regaddr,regaddr_3ld,regaddralias,routerinfo,vain,verifyhost,x25519} /out/android/x86_64/


##############################################################
exit 0
# TODO: make this compile.



cd $BUILD_DIR
git clone --recursive https://github.com/purplei2p/i2pd-tools i2pd-tools-arm64-v8a
cp -a i2pd-tools-arm64-v8a i2pd-tools-armeabi-v7a
cp -a i2pd-tools-arm64-v8a i2pd-tools-x86
cp -a i2pd-tools-arm64-v8a i2pd-tools-x86_64
for arch in arm64-v8a armeabi-v7a x86 x86_64;
do
    cd $BUILD_DIR/i2pd-tools-$arch
    sed 's/LDFLAGS = /LDFLAGS = -static/g' -i Makefile
    sed 's/\$(MAKE) -C \$(I2PD_PATH) mk_obj_dir \$(I2PD_LIB)/echo \$(MAKE) -C \$(I2PD_PATH) mk_obj_dir \$(I2PD_LIB)/g' -i Makefile
    sed "s/INCFLAGS = -I../i2pd-android/app/jni/openssl/out/$arch/include -I../i2pd-android/app/jni/boost/build/out/$arch/include -/-/g" -i Makefile
    # -I../i2pd-android/app/jni/openssl/out/x86_64/include -I../i2pd-android/app/jni/boost/build/out/x86_64/include
    #rm -rf i2pd
    #ln -s ../i2pd-android/binary/jni/i2pd
    for task in b33address famtool i2pbase64 keygen keyinfo offlinekeys regaddr regaddr_3ld regaddralias routerinfo vain verifyhost x25519;
    do
        CXX=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android21-clang++ make $task -j1
    done
done
$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android21-clang

# mv b33address famtool i2pbase64 keygen keyinfo offlinekeys regaddr regaddr_3ld regaddralias routerinfo vain verifyhost x25519 /out/linux_"$ARCH"
# strip /out/linux_"$ARCH"/*


# echo "$ pwd" > build_info.txt
# pwd >> build_info.txt
# echo "$ uname -a" > build_info.txt
# uname -a >> build_info.txt
# echo "$ cat /etc/os-release" > build_info.txt
# cat /etc/os-release >> build_info.txt
# echo "$ cmake .. -L" >> build_info.txt
# cmake .. -L >> build_info.txt