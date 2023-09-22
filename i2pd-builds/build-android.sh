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

export I2PD_ANDROID_BRANCH="2.49.0"
export I2PD_TOOLS_ANDROID_BRANCH="2.47.0"

for branch in $I2PD_TOOLS_ANDROID_BRANCH $I2PD_ANDROID_BRANCH;
do
    cd $BUILD_DIR
    git clone --recurse-submodules https://github.com/PurpleI2P/i2pd-android.git -b $branch i2pd-android-$branch

    cd i2pd-android-$branch

    cd binary/jni
    ./build_boost.sh
    ./build_openssl.sh
    ./build_miniupnpc.sh
    $ANDROID_NDK_HOME/ndk-build -j $(nproc --all) NDK_MODULE_PATH=$PWD
done
cd ../libs
mkdir -p /out/android/{arm64-v8a,armeabi-v7a,x86,x86_64}
cp -a arm64-v8a/i2pd /out/android/arm64-v8a/
cp -a armeabi-v7a/i2pd /out/android/armeabi-v7a/
cp -a x86/i2pd /out/android/x86/
cp -a x86_64/i2pd /out/android/x86_64/

cd $BUILD_DIR
git clone --recursive https://github.com/purplei2p/i2pd-tools i2pd-tools-arm64-v8a
cp -a i2pd-tools-arm64-v8a i2pd-tools-armeabi-v7a
cp -a i2pd-tools-arm64-v8a i2pd-tools-x86
cp -a i2pd-tools-arm64-v8a i2pd-tools-x86_64
# screw armeabi-v7a and x86
for arch in arm64-v8a x86_64;
do
    cd $BUILD_DIR/i2pd-tools-$arch
    #  -static -ffunction-sections -fdata-sections -Wl,--gc-sections
    # https://github.com/termux/termux-packages/issues/8273#issuecomment-1133861593
    sed 's/LDFLAGS = /LDFLAGS = -static -ffunction-sections -fdata-sections -Wl,--gc-sections /g' -i Makefile
    sed 's/\$(MAKE) -C \$(I2PD_PATH) mk_obj_dir \$(I2PD_LIB)/echo \$(MAKE) -C \$(I2PD_PATH) mk_obj_dir \$(I2PD_LIB)/g' -i Makefile
    sed "s/INCFLAGS = -/INCFLAGS = -I..\/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH\/app\/jni\/openssl\/out\/$arch\/include -I..\/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH\/app\/jni\/boost\/build\/out\/$arch\/include -/g" -i Makefile
    rm -rf i2pd
    ln -s ../i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH/binary/jni/i2pd
    # produce libi2pd.a
    export OBJ_DIR="$(realpath $BUILD_DIR/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH/binary/obj/local/$arch/objs/i2pd/$BUILD_DIR/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH/binary/jni)"
    (
        cd $OBJ_DIR &&
        $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar -r libi2pd.a i2pd/libi2pd/{Base,Blinding,CPU,ChaCha20,Config,Crypto,CryptoKey,Datagram,Destination,ECIESX25519AEADRatchetSession,Ed25519,Elligator,FS,Family,Garlic,Gost,Gzip,HTTP,I2NPProtocol,I2PEndian,Identity,KadDHT,LeaseSet,Log,NTCP2,NetDb,NetDbRequests,Poly1305,Profiling,Reseed,RouterContext,RouterInfo,SSU2,SSU2Session,Signature,Streaming,Timestamp,TransitTunnel,Transports,Tunnel,TunnelConfig,TunnelEndpoint,TunnelGateway,TunnelPool,api,util}.o
    )
    mv $OBJ_DIR/libi2pd.a i2pd/
    # end produce libi2pd.a
    # fix libraries
    # libboost_atomic.a           libboost_date_time.a        libboost_filesystem.a       libboost_program_options.a  libboost_system.a
    sed "s/-lboost_system/..\/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH\/app\/jni\/boost\/build\/out\/$arch\/lib\/libboost_system.a/g" -i Makefile
    sed "s/-lboost_date_time/..\/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH\/app\/jni\/boost\/build\/out\/$arch\/lib\/libboost_date_time.a/g" -i Makefile
    sed "s/-lboost_filesystem/..\/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH\/app\/jni\/boost\/build\/out\/$arch\/lib\/libboost_filesystem.a/g" -i Makefile
    sed "s/-lboost_program_options/..\/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH\/app\/jni\/boost\/build\/out\/$arch\/lib\/libboost_program_options.a/g" -i Makefile
    sed "s/-lcrypto/..\/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH\/app\/jni\/openssl\/out\/$arch\/lib\/libcrypto.a/g" -i Makefile
    sed "s/-lssl/..\/i2pd-android-$I2PD_TOOLS_ANDROID_BRANCH\/app\/jni\/openssl\/out\/$arch\/lib\/libssl.a/g" -i Makefile
    sed "s/-lpthread//g" -i Makefile
    sed "s/-lrt/-ldl/g" -i Makefile # -ldl is ***NOT*** replacement for -lrt - i just need to throw it into ldflags

    for task in b33address famtool i2pbase64 keygen keyinfo offlinekeys regaddr regaddr_3ld regaddralias routerinfo vain verifyhost x25519;
    do
        ndkarch="$arch"
        eabi=""
        [[ "$arch" == "arm64-v8a" ]] && ndkarch="aarch64"
        [[ "$arch" == "armeabi-v7a" ]] && ndkarch="armv7a"
        [[ "$arch" == "armeabi-v7a" ]] && eabi="eabi" # why.
        [[ "$arch" == "x86" ]] && ndkarch="i686"
        [[ "$arch" == "x86_64" ]] && ndkarch="x86_64"

        CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/$ndkarch-linux-android"$eabi"21-clang \
        CXX=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/$ndkarch-linux-android"$eabi"21-clang++ \
        make $task -j1
        $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip $task
        cp $task /out/android/$arch/
    done
done

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