import 'dart:io';

import 'package:dart_i2p/src/switch_platform.dart';

enum I2pdBinaries {
  b33address,
  famtool,
  i2pbase64,
  i2pd,
  keygen,
  keyinfo,
  offlinekeys,
  regaddr,
  regaddr_3ld,
  regaddralias,
  routerinfo,
  vain,
  verifyhost,
  x25519,
}

/// get binary path in platform-native way
/// in other words, treat android and windows with special care because whatever
String i2pdBinariesToString(I2pdBinaries bin) {
  final prefix = switch (getPlatform()) {
    OS.android => 'lib',
    _ => '',
  };
  final suffix = switch (getPlatform()) {
    OS.windows => '.exe',
    OS.android => '.so',
    _ => '',
  };
  return switch (bin) {
    I2pdBinaries.b33address => '${prefix}b33address$suffix',
    I2pdBinaries.famtool => '${prefix}famtool$suffix',
    I2pdBinaries.i2pbase64 => '${prefix}i2pbase64$suffix',
    I2pdBinaries.i2pd => '${prefix}i2pd$suffix',
    I2pdBinaries.keygen => '${prefix}keygen$suffix',
    I2pdBinaries.keyinfo => '${prefix}keyinfo$suffix',
    I2pdBinaries.offlinekeys => '${prefix}offlinekeys$suffix',
    I2pdBinaries.regaddr => '${prefix}regaddr$suffix',
    I2pdBinaries.regaddr_3ld => '${prefix}regaddr_3ld$suffix',
    I2pdBinaries.regaddralias => '${prefix}regaddralias$suffix',
    I2pdBinaries.routerinfo => '${prefix}routerinfo$suffix',
    I2pdBinaries.vain => '${prefix}vain$suffix',
    I2pdBinaries.verifyhost => '${prefix}verifyhost$suffix',
    I2pdBinaries.x25519 => '${prefix}x25519$suffix',
  };
}
