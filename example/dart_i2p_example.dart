// ignore: unused_import
import 'package:dart_i2p/dart_i2p.dart';

Future<void> main() async {
  final i2p = I2p(
    storePathString: "/home/user/.i2pd-temp-dart",
    // this is very platform specyfic, I know.
    // I'm also aware of the fact that this is not a go project
    binPath:
        "/home/user/go/src/git.mrcyjanek.net/p3pch4t/dart_i2p/i2pd-builds/out/linux_amd64",
    tunnels: [
      I2pdHttpTunnel(
        name: 'testhttp',
        host: '127.0.0.1',
        port: 8989,
        inport: 8989,
        keys: 'testhttpkeys.dat',
      )
    ],
    i2pdConf: I2pdConf(
      loglevel: "warn",
      port: I2pdConf.getPort(),
      ntcp2: I2pdNtcp2Conf(),
      ssu2: I2pdSsu2Conf(),
      http: I2pdHttpConf(auth: false),
      httpproxy: I2pdHttpproxyConf(),
      socksproxy: I2pdSocksproxyConf(),
      sam: I2pdSamConf(),
      bob: I2pdBobConf(),
      i2cp: I2pdI2cpConf(),
      i2pcontrol: I2pdI2pcontrolConf(),
      precomputation: I2pdPrecomputationConf(),
      upnp: I2pdUpnpConf(),
      meshnets: I2pdMeshnetsConf(),
      reseed: I2pdReseedConf(),
      addressbook: I2pdAddressbookConf(),
      limits: I2pdLimitsConf(),
      trust: I2pdTrustConf(),
      exploratory: I2pdExploratoryConf(),
      persist: I2pdPersistConf(),
      cpuext: I2pdCpuextConf(),
    ),
  );
  final di = await i2p.domainInfo('testhttpkeys.dat');
  print("di = '$di'");
  // final ec = await i2p.run();
  // print('exitc code: $ec');
}
