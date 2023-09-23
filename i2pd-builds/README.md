# Building I2PD

This is not a easy task to achieve, while building linux is pretty straight forward

windows:

```plain
$ pacman -S upx parallel # build.sh dependencies
$ pacman -S mingw-w64-i686-boost mingw-w64-i686-openssl mingw-w64-i686-zlib mingw-w64-i686-gcc make
$ pacman -S mingw-w64-x86_64-boost mingw-w64-x86_64-openssl  mingw-w64-x86_64-zlib mingw-w64-x86_64-gcc
# Then cd into this directory (clone flutter_i2p_bins-prebuild if you wish to contribute to prebuilds)
$ ./build-windows.sh
```

linux/android:

```
$ sudo ./build.sh
```