// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path/path.dart' as p;
import 'package:dart_i2p/src/certgen/gen_certs.g.dart' as crts;

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random.secure();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

class I2p {
  I2p({
    required String storePathString,
    required this.i2pdConf,
    required this.binPath,
    this.tunnels = const [],

    /// enables i2pdConf.httpproxy.enabled and provides non-null this.dio
    bool addHttpProxy = false,
    this.populateCertsDirectory = true,
    this.libSoHack = false,
  }) {
    if (addHttpProxy) {
      i2pdConf.httpproxy.enabled = true;
      final adapter = IOHttpClientAdapter()
        ..createHttpClient = () {
          final client = HttpClient();
          client.findProxy = (uri) {
            return 'PROXY localhost:${i2pdConf.httpproxy.port}';
          };
          return client;
        };
      _dio = Dio()..httpClientAdapter = adapter;
    }
    storePath = Directory(storePathString)..createSync(recursive: true);

    config = I2pRuntimeConfig(
      conf: _i2pdConf.path,
      tunconf: _tunnelsConf.path,
      datadir: _i2pdData.path,
    );
    Directory(p.join(_i2pdData.path, 'keys')).createSync(recursive: true);

    i2pdConf.tunconf = _tunnelsConf.path;
    i2pdConf.tunnelsdir = "${_tunnelsConf.path}.d";
    i2pdConf.certsdir = p.join(storePathString, 'certificates');
  }

  /// use lib<executable>.so name instead of <executable> to run binaries.
  bool libSoHack = false;

  Dio? _dio;

  /// Dio() configured to be used with i2p network, you must set addHttpProxy
  /// to true when creating I2p object to have Dio set.
  Dio? get dio => _dio;

  /// Enable to put contrib/certificates into the filesystem
  /// this is required for the i2pd to function properly, it is recommended
  /// to keep this 'true' unless you have a really got reason not to.
  bool populateCertsDirectory = true;

  /// Tunnels stored as objects - that later will be saved into this.tunconf
  /// file.
  List<I2pdTunnel> tunnels = [];

  /// Place in which bineries reside.
  /// It should contain at least:
  /// - [x] i2pd
  /// - [x] keyinfo
  /// And optionally (not used currently, but we may use them in future.)
  /// - [ ] b33address
  /// - [ ] famtool
  /// - [ ] i2pbase64
  /// - [ ] keygen
  /// - [ ] keyinfo
  /// - [ ] offlinekeys
  /// - [ ] regaddr
  /// - [ ] regaddr_3ld
  /// - [ ] regaddralias
  /// - [ ] routerinfo
  /// - [ ] vain
  /// - [ ] verifyhost
  /// - [ ] x25519
  /// To ensure full compatibility with
  String binPath;
  Future<int> run() async {
    await _i2pdConf.writeAsString(i2pdConf.toString());
    final tunnelsSink = _tunnelsConf.openWrite(mode: FileMode.write);
    for (var tunnel in tunnels) {
      tunnelsSink.writeln(tunnel.toString());
    }
    await tunnelsSink.flush();
    await tunnelsSink.close();

    if (populateCertsDirectory) {
      final family = Directory(p.join(i2pdConf.certsdir, 'family'));
      await family.create(recursive: true);
      final reseed = Directory(p.join(i2pdConf.certsdir, 'reseed'));
      await reseed.create(recursive: true);
      crts.family.forEach((String filename, String content) {
        File(p.join(family.path, filename))
          ..createSync(recursive: true)
          ..writeAsStringSync(content);
      });
      crts.reseed.forEach((String filename, String content) {
        File(p.join(reseed.path, filename))
          ..createSync(recursive: true)
          ..writeAsStringSync(content);
      });
    }
    final bin = p.join(binPath, libSoHack ? 'libi2pd.so' : "i2pd");
    final ps = await Process.run(
      bin,
      config.toString().split(' '),
    );

    print("bin: $bin $config");
    print(ps.stdout);
    print(ps.stderr);
    //stdout.addStream(ps.stdout);
    //stderr.addStream(ps.stderr);
    return ps.exitCode;
  }

  late I2pRuntimeConfig config;

  late final Directory storePath;
  I2pdConf i2pdConf;
  File get _i2pdConf => File(p.join(storePath.path, "i2pd.conf"));
  File get _tunnelsConf => File(p.join(storePath.path, "tunnels.conf"));
  Directory get _i2pdData => Directory(p.join(storePath.path, "i2pddata"));

  Future<String?> domainInfo(String keyfilename) async {
    final run = await Process.run(
      p.join(binPath, libSoHack ? 'libkeyinfo.so' : "keyinfo"),
      [
        p.join(
          _i2pdData.path,
          'keys',
          keyfilename,
        )
      ],
    );
    return run.stdout.toString().split("\n")[0];
  }
}

class I2pRuntimeConfig {
  I2pRuntimeConfig({
    required this.conf,
    required this.tunconf,
    required this.datadir,
    this.service = false,
    @Deprecated("use I2pdConf.pidfile instead") this.pidfile,
    @Deprecated("use I2pdConf.log instead") this.log,
    @Deprecated("use I2pdConf.logfile instead") this.logfile,
    @Deprecated("use I2pdConf.loglevel instead") this.loglevel,
    @Deprecated("use I2pdConf.logclftime instead") this.logclftime,
    @Deprecated("use I2pdConf.host instead") this.host,
    @Deprecated("use I2pdConf.port instead") this.port,
    @Deprecated("use I2pdConf.daemon instead") this.daemon,
    @Deprecated("use I2pdConf.ifname instead") this.ifname,
    @Deprecated("use I2pdConf.ifname4 instead") this.ifname4,
    @Deprecated("use I2pdConf.ifname6 instead") this.ifname6,
    @Deprecated("use I2pdConf.address4 instead") this.address4,
    @Deprecated("use I2pdConf.address6 instead") this.address6,
    @Deprecated("use I2pdConf.nat instead") this.nat,
    @Deprecated("use I2pdConf.ipv4 instead") this.ipv4,
    @Deprecated("use I2pdConf.ipv6 instead") this.ipv6,
    @Deprecated("use I2pdConf.notransit instead") this.notransit,
    @Deprecated("use I2pdConf.floodfill instead") this.floodfill,
    @Deprecated("use I2pdConf.bandwidth instead") this.bandwidth,
    @Deprecated("use I2pdConf.share instead") this.share,
    @Deprecated("use I2pdConf.family instead") this.family,
  });

  /// Config file (default: ~/.i2pd/i2pd.conf or /var/lib/i2pd/i2pd.conf). This
  /// parameter will be silently ignored if the specified config file does not
  /// exist.
  String conf;

  /// Tunnels config file (default = ~/.i2pd/tunnels.conf or
  /// /var/lib/i2pd/tunnels.conf)
  String tunconf;

  /// Where to write pidfile (default = i2pd.pid, not used in Windows)
  String? pidfile;

  /// Logs destination: stdout, file, syslog (stdout if not set or invalid) (if
  /// daemon, stdout/unspecified are replaced by file in some cases)
  String? log;

  /// Path to logfile (default - autodetect)
  @Deprecated("use I2pdConf.logfile instead")
  String? logfile;

  /// Log messages above this level (debug, info, warn, error, none; default - warn)
  @Deprecated("use I2pdConf.loglevel instead")
  String? loglevel;

  /// Write full CLF-formatted date and time to log (default = false (write only time))
  @Deprecated("use I2pdConf.logclftime instead")
  bool? logclftime;

  /// Path to storage of i2pd data (RouterInfos, destinations keys, peer profiles, etc ...)
  String datadir;

  /// Router external IP for incoming connections (default = auto if SSU2 is enabled)
  @Deprecated("use I2pdConf.host instead")
  String? host;

  /// Port to listen for incoming connections (default = auto (random))
  @Deprecated("use I2pdConf.port instead")
  int? port;

  /// Router will go to background after start (default = true)
  @Deprecated("use I2pdConf.daemon instead")
  bool? daemon = true;

  /// Router will use system folders like '/var/lib/i2pd' (on unix) or 'C:\ProgramData\i2pd' (on Windows). Ignored on MacOS and Android (default = false)
  bool service = false;

  /// Network interface to bind to
  @Deprecated("use I2pdConf.ifname instead")
  String? ifname;

  /// Network interface to bind to for IPv4
  @Deprecated("use I2pdConf.ifname4 instead")
  String? ifname4;

  /// Network interface to bind to for IPv6
  @Deprecated("use I2pdConf.ifname6 instead")
  String? ifname6;

  /// Local address to bind to for IPv4
  @Deprecated("use I2pdConf.address4 instead")
  String? address4;

  /// Local address to bind to for clearnet IPv6
  @Deprecated("use I2pdConf.address6 instead")
  String? address6;

  /// If true, assume we are behind NAT (default = true)
  @Deprecated("use I2pdConf.nat instead")
  bool? nat;

  /// Enable communication through IPv4 (default = true)
  @Deprecated("use I2pdConf.ipv4 instead")
  bool? ipv4;

  /// Enable communication through clearnet IPv6 (default = false)
  @Deprecated("use I2pdConf.ipv6 instead")
  bool? ipv6;

  /// Router will not accept transit tunnels, disabling transit traffic completely. G router cap will be published (default = false)
  @Deprecated("use I2pdConf.notransit instead")
  bool? notransit;

  /// Router will be floodfill (default = false)
  @Deprecated("use I2pdConf.floodfill instead")
  bool? floodfill;

  /// Bandwidth limit: integer in KBps or letters: L (32), O (256), P (2048), X (unlimited).
  @Deprecated("use I2pdConf.floodfill instead")
  int? bandwidth;

  /// Max % of bandwidth limit for transit. 0-100 (default = 100)
  @Deprecated("use I2pdConf.share instead")
  int? share;

  /// Name of a family, router belongs to
  @Deprecated("use I2pdConf.family instead")
  String? family;

  /// Network ID, router belongs to. Main I2P is 2.
  final int netid = 2;

  @override
  String toString() {
    return [
      "--conf $conf",
      "--tunconf $tunconf",
      if (pidfile != null) "--pidfile $pidfile",
      if (log != null) "--log $log",
      if (logfile != null) "--logfile $logfile",
      if (loglevel != null) "--loglevel $loglevel",
      if (logclftime != null) "--logclftime $logclftime",
      "--datadir $datadir",
      if (host != null) "--host $host",
      if (port != null) "--port $port",
      if (daemon != null) "--daemon $daemon",
      "--service $service",
      if (ifname != null) "--ifname $ifname",
      if (ifname4 != null) "--ifname4 $ifname4",
      if (ifname6 != null) "--ifname6 $ifname6",
      if (address4 != null) "--address4 $address4",
      if (address6 != null) "--address6 $address6",
      if (nat != null) "--nat $nat",
      if (ipv4 != null) "--ipv4 $ipv4",
      if (ipv6 != null) "--ipv6 $ipv6",
      if (notransit != null) "--notransit $notransit",
      if (floodfill != null) "--floodfill $floodfill",
      if (bandwidth != null) "--bandwidth $bandwidth",
      if (share != null) "--share $share",
      if (family != null) "--family $family",
      "--netid 2"
    ].join(" ");
  }
}

/// Configuration file for a typical i2pd user
/// See https://i2pd.readthedocs.io/en/latest/user-guide/configuration/
/// for more options you can use in this file.
class I2pdConf {
  static int getPort() => Random().nextInt(30777 - 9111) + 9111;

  I2pdConf({
    this.tunconf = "~/.i2pd/tunnels.conf",
    this.tunnelsdir = "~/.i2pd/tunnels.d",
    this.certsdir = "~/.i2pd/certificates",
    required this.port,
    this.pidfile,
    this.log,
    this.logfile,
    this.loglevel,
    this.logclftime,
    this.daemon,
    this.family,
    this.ifname,
    this.ifname4,
    this.ifname6,
    this.address4,
    this.address6,
    this.host,
    this.ipv4 = true,
    this.ipv6 = false,
    this.bandwidth = 256,
    this.share = 100,
    this.notransit = false,
    this.floodfill = false,
    required this.ntcp2,
    required this.ssu2,
    required this.http,
    required this.httpproxy,
    required this.socksproxy,
    required this.sam,
    required this.bob,
    required this.i2cp,
    required this.i2pcontrol,
    required this.precomputation,
    required this.upnp,
    required this.meshnets,
    required this.reseed,
    required this.addressbook,
    required this.limits,
    required this.trust,
    required this.exploratory,
    required this.persist,
    required this.cpuext,
  });

  /// Tunnels config file
  /// Default: ~/.i2pd/tunnels.conf or /var/lib/i2pd/tunnels.conf
  String tunconf = "~/.i2pd/tunnels.conf";

  /// Tunnels config files path
  /// Use that path to store separated tunnels in different config files.
  /// Default: ~/.i2pd/tunnels.d or /var/lib/i2pd/tunnels.d
  String tunnelsdir = "~/.i2pd/tunnels.d";

  /// Path to certificates used for verifying .su3, families
  /// Default: ~/.i2pd/certificates or /var/lib/i2pd/certificates
  String certsdir = "/var/lib/i2pd/certificates";

  /// Where to write pidfile (default: /run/i2pd.pid, not used in Windows)
  String? pidfile;

  ///  Logging configuration section
  /// By default logs go to stdout with level 'info' and higher
  /// For Windows OS by default logs go to file with level 'warn' and higher
  ///
  /// Logs destination (valid values: stdout, file, syslog)
  ///  * stdout - print log entries to stdout
  ///  * file - log entries to a file
  ///  * syslog - use syslog, see man 3 syslog
  String? log;

  /// Path to logfile (default: autodetect)
  String? logfile;

  /// Log messages above this level (debug, info, *warn, error, critical, none)
  /// If you set it to none, logging will be disabled
  String? loglevel;

  /// Write full CLF-formatted date and time to log (default: write only time)
  bool? logclftime;

  /// Daemon mode. Router will go to background after start. Ignored on Windows
  bool? daemon;

  /// Specify a family, router belongs to (default - none)
  String? family;

  /// Network interface to bind to
  /// Updates address4/6 options if they are not set
  String? ifname;

  /// You can specify different interfaces for IPv4 and IPv6
  String? ifname4;

  /// You can specify different interfaces for IPv4 and IPv6
  String? ifname6;

  /// Local address to bind transport sockets to
  /// Overrides host option if:
  /// For ipv4: if ipv4 = true and nat = false
  String? address4;

  /// Local address to bind transport sockets to
  /// Overrides host option if:
  /// For ipv6: if 'host' is set or ipv4 = true
  String? address6;

  /// External IPv4 or IPv6 address to listen for connections
  /// By default i2pd sets IP automatically
  /// Sets published NTCP2v4/SSUv4 address to 'host' value if nat = true
  /// Sets published NTCP2v6/SSUv6 address to 'host' value if ipv4 = false
  String? host;

  /// Port to listen for connections
  /// By default i2pd picks random port. You MUST pick a random number too,
  /// By default it returns a random number from the range of 9111 to 30777
  /// https://github.com/PurpleI2P/i2pd/blob/1e7fea/libi2pd/RouterContext.cpp#L241
  late int port = Random().nextInt(30777 - 9111) + 9111;

  /// Enable communication through ipv4 (default = true)
  bool ipv4 = true;

  /// Enable communication through ipv6 (default = false)
  bool ipv6 = false;

  /// Bandwidth configuration
  /// L limit bandwidth to 32 KB/sec, O - to 256 KB/sec, P - to 2048 KB/sec,
  /// X - unlimited
  /// Default is L (regular node) and X if floodfill mode enabled.
  /// If you want to share more bandwidth without floodfill mode, uncomment
  /// that line and adjust value to your possibilities. Value can be set to
  /// integer in kilobytes, it will apply that limit and flag will be used
  /// from next upper limit (example = if you set 4096 flag will be X, but real
  /// limit will be 4096 KB/s). Same can be done when floodfill mode is used,
  /// but keep in mind that low values may be negatively evaluated by Java
  /// router algorithms.
  /// NOTE: For the sake of implementing this feature (and using it) easily
  /// letters are not allowed, use `int' instead
  int bandwidth = 256;

  /// Max % of bandwidth limit for transit. 0-100 (default = 100)
  int share = 100;

  /// Router will not accept transit tunnels, disabling transit traffic completely
  bool notransit = false;

  /// Router will be floodfill (default = false)
  /// Note: that mode uses much more network connections and CPU!
  bool floodfill = false;

  /// i2pd.conf [ntcp2] config
  I2pdNtcp2Conf ntcp2;

  /// i2pd.conf [ssu2] config
  I2pdSsu2Conf ssu2;

  /// i2pd.conf [http] config
  I2pdHttpConf http;

  /// i2pd.conf [httpproxy] config
  I2pdHttpproxyConf httpproxy;

  /// i2pd.conf [socksproxy] config
  I2pdSocksproxyConf socksproxy;

  /// i2pd.conf [sam] config
  I2pdSamConf sam;

  /// i2pd.conf [bob] config
  I2pdBobConf bob;

  /// i2pd.conf [i2cp] config
  I2pdI2cpConf i2cp;

  /// i2pd.conf [i2pcontrol] config
  I2pdI2pcontrolConf i2pcontrol;

  /// i2pd.conf [precomputation] config
  I2pdPrecomputationConf precomputation;

  /// i2pd.conf [upnp] config
  I2pdUpnpConf upnp;

  /// i2pd.conf [meshnets] config
  I2pdMeshnetsConf meshnets;

  /// i2pd.conf [reseed] config
  I2pdReseedConf reseed;

  /// i2pd.conf [addressbook] config
  I2pdAddressbookConf addressbook;

  /// i2pd.conf [limits] config
  I2pdLimitsConf limits;

  /// i2pd.conf [trust] config
  I2pdTrustConf trust;

  /// i2pd.conf [exploratory] config
  I2pdExploratoryConf exploratory;

  /// i2pd.conf [persist] config
  I2pdPersistConf persist;

  /// i2pd.conf [cpuext] config
  I2pdCpuextConf cpuext;

  @override
  String toString() {
    return '''
tunconf = $tunconf
tunnelsdir = $tunnelsdir
certsdir = $certsdir
${pidfile == null ? '# ' : ''}pidfile = $pidfile
${log == null ? '# ' : ''}log = $log
${logfile == null ? '# ' : ''}logfile = $logfile
${loglevel == null ? '# ' : ''}loglevel = $loglevel
${logclftime == null ? '# ' : ''}logclftime = $logclftime
${daemon == null ? '# ' : ''}daemon = $daemon
${family == null ? '# ' : ''}family = $family
${ifname == null ? '#' : ''}ifname = $ifname
${ifname4 == null ? '#' : ''}ifname4 = $ifname4
${ifname6 == null ? '#' : ''}ifname6 = $ifname6
${address4 == null ? '#' : ''}address4 = $address4
${address6 == null ? '#' : ''}address6 = $address6
${host == null ? '#' : ''}host = $host
port = $port
ipv4 = $ipv4
ipv6 = $ipv6
bandwidth = $bandwidth
share = $share
notransit = $notransit
floodfill = $floodfill
$ntcp2
$ssu2
$http
$httpproxy
$socksproxy
$sam
$bob
$i2cp
$i2pcontrol
$precomputation
$upnp
$meshnets
$reseed
$addressbook
$limits
$trust
$exploratory
$persist
$cpuext
''';
  }
}

/// i2pd.conf [ntcp2] config
class I2pdNtcp2Conf {
  I2pdNtcp2Conf({
    this.enabled = true,
    this.published = true,
    this.port,
  });

  /// Enable NTCP2 transport (default = true)
  bool enabled = true;

  /// Publish address in RouterInfo (default = true)
  bool published = true;

  ///  Port for incoming connections (default is global port option value)
  int? port;

  @override
  String toString() {
    return '''
[ntcp2]
enabled = $enabled
published = $published
${port == null ? '#' : ''}port = $port
''';
  }
}

/// i2pd.conf [ssu2] config
class I2pdSsu2Conf {
  I2pdSsu2Conf({
    this.enabled = true,
    this.published = true,
    this.port,
  });

  /// Enable SSU2 transport (default = true)
  bool enabled = true;

  /// Publish address in RouterInfo (default = true)
  bool published = true;

  /// Port for incoming connections (default is global port option value)
  int? port;
  @override
  String toString() {
    return '''
[ssu2]
enabled = $enabled
published = $published
${port == null ? '#' : ''}port = $port
''';
  }
}

/// i2pd.conf [http] config
class I2pdHttpConf {
  I2pdHttpConf({
    this.enabled = true,
    this.address = "127.0.0.1",
    this.port = 7070,

    /// Path to web console (default = /)
    /// i2pd's default: /
    /// our default: /<random 16 characters>
    String? webroot,
    this.auth = true,
    this.user = "i2pd",

    /// http auth password (make sure to set auth=true)
    String? pass,
    this.lang = "english",
    this.strictheaders = false,
  }) {
    if (webroot == null) _webroot = "/${getRandomString(16)}";
    if (pass == null) _pass = getRandomString(16);
  }

  /// Web Console settings
  /// Enable the Web Console (default = true)
  bool enabled = true;

  /// Address and port service will listen on (default = 127.0.0.1:7070)
  String address = "127.0.0.1";
  int port = 7070;

  /// Path to web console (default = /)
  /// i2pd's default: /
  /// our default: /<random 16 characters>
  String _webroot = "/${getRandomString(16)}";

  /// Enable Web Console authentication (default = false)
  /// You should not use Web Console via public networks without additional encryption.
  /// HTTP authentication is not encryption layer!
  /// Make sure to set username and password)
  bool auth = true;

  /// http auth username (make sure to set auth=true)
  String user = "i2pd";

  /// http auth password (make sure to set auth=true)
  String _pass = getRandomString(16);

  /// Select webconsole language
  /// Currently supported english (default), afrikaans, armenian, chinese, czech, french,
  /// german, italian, polish, portuguese, russian, spanish, turkish, turkmen, ukrainian
  /// and uzbek languages
  String lang = "english";

  /// https://github.com/PurpleI2P/i2pd/blob/918aa55/daemon/HTTPServer.cpp#L1153
  bool strictheaders = false;

  @override
  String toString() {
    return '''
[http]
enabled = $enabled
address = $address
port = $port
webroot = $_webroot
auth = $auth
user = $user
pass = $_pass
lang = $lang
''';
  }
}

/// i2pd.conf [httpproxy] config
class I2pdHttpproxyConf {
  I2pdHttpproxyConf({
    this.enabled = true,
    this.address = "127.0.0.1",
    this.port = 4444,
    this.keys = "http-proxy-keys.dat",
    this.addresshelper = false,
    this.outproxy,
  });

  /// Enable the HTTP proxy (default = true)
  bool enabled = true;

  /// Address that this service will listen on (default = 127.0.0.1)
  String address = "127.0.0.1";

  /// Port that this service will listen on (default = 4444)

  int port = 4444;

  /// Optional keys file for proxy local destination (default = http-proxy-keys.dat)
  String keys = "http-proxy-keys.dat";

  /// Enable address helper for adding .i2p domains with "jump URLs" (default = true)
  /// You should disable this feature if your i2pd HTTP Proxy is public,
  /// because anyone could spoof the short domain via addresshelper and forward other users to phishing links
  /// NOTE, I've decided to turn this off since other apps could possibly
  /// send requests to the :4444 port and cause some trouble for the app.
  bool addresshelper = false;

  /// Address of a proxy server inside I2P, which is used to visit regular Internet
  /// for example "http://false.i2p"
  String? outproxy;
// httpproxy section also accepts I2CP parameters, like "inbound.length" etc.

  @override
  String toString() {
    return '''
[httpproxy]
enabled = $enabled
address = $address
port = $port
keys = keys/$keys
addresshelper = $addresshelper
outproxy = $outproxy
''';
  }
}

/// i2pd.conf [socksproxy] config
class I2pdSocksproxyConf {
  I2pdSocksproxyConf({
    this.enabled = true,
    this.address = "127.0.0.1",
    this.port = 4447,
    this.keys = "socks-proxy-keys.dat",
    this.outproxyEnabled = false,
    this.outproxy = "127.0.0.1",
    this.outproxyport = 9050,
  });

  /// Enable the SOCKS proxy (default = true)
  bool enabled = true;

  /// Address and port service will listen on (default = 127.0.0.1:4447)
  String address = "127.0.0.1";
  int port = 4447;

  /// Optional keys file for proxy local destination (default = socks-proxy-keys.dat)
  String keys = "socks-proxy-keys.dat";

  /// Socks outproxy. Example below is set to use Tor for all connections except i2p
  /// Enable using of SOCKS outproxy (works only with SOCKS4, default: false)
  /// key: outproxy.enabled
  bool outproxyEnabled = false;

  /// Address of outproxy
  String outproxy = "127.0.0.1";

  /// Port of outproxy
  int outproxyport = 9050;
// socksproxy section also accepts I2CP parameters, like "inbound.length" etc.
  @override
  String toString() {
    return '''
[socksproxy]
enabled = $enabled
address = $address
port = $port
keys = keys/$keys
outproxy.enabled = $outproxyEnabled
outproxy = $outproxy
outproxyport = $outproxyport
''';
  }
}

/// i2pd.conf [sam] config
class I2pdSamConf {
  I2pdSamConf({
    this.enabled = false,
    this.address = "127.0.0.1",
    this.port = 7657,
    this.portudp = 7655,
  });

  /// Enable the SAM bridge (default = true)
  bool enabled = false;

  /// Address service will listen on (default = 127.0.0.1)
  String address = "127.0.0.1";

  /// Port service will listen on (default = 7656)
  int port = 7656;

  /// Port service will listen on (default = 7655)
  int portudp = 7655;

  @override
  String toString() {
    return '''
[sam]
enabled = $enabled
address = $address
port = $port
portudp = $portudp
''';
  }
}

/// i2pd.conf [bob] config
class I2pdBobConf {
  I2pdBobConf({
    this.enabled = false,
    this.address = "127.0.0.1",
    this.port = 2827,
  });

  /// Enable the BOB command channel (default = false)
  bool enabled = false;

  /// Address service will listen on (default = 127.0.0.1)
  String address = "127.0.0.1";

  /// Port service will listen on (default = 2827)
  int port = 2827;

  @override
  String toString() {
    return '''
[bob]
enabled = $enabled
address = $address
port = $port
''';
  }
}

/// i2pd.conf [i2cp] config
class I2pdI2cpConf {
  I2pdI2cpConf({
    this.enabled = false,
    this.address = "127.0.0.1",
    this.port = 7654,
  });

  /// Enable the I2CP protocol (default = false)
  bool enabled = false;

  /// Address this service will listen on (default = 127.0.0.1)
  String address = "127.0.0.1";

  /// Port service will listen on (default = 7654)
  int port = 7654;

  @override
  String toString() {
    return '''
[i2cp]
enabled = $enabled
address = $address
port = $port
''';
  }
}

/// i2pd.conf [i2pcontrol] config
class I2pdI2pcontrolConf {
  I2pdI2pcontrolConf({
    this.enabled = false,
    this.address = "127.0.0.1",
    this.port = 7650,

    /// Authentication password (default = random 16 characters)
    String? password,
  }) {
    _password = password ?? getRandomString(16);
  }

  /// Enable the I2PControl protocol (default = false)
  bool enabled = false;

  /// Address and port service will listen on (default = 127.0.0.1)
  String address = "127.0.0.1";

  /// Address and port service will listen on (default = 7650)
  int port = 7650;

  /// Authentication password (default = random 16 characters)
  String _password = getRandomString(16);

  String getPassword() => _password;

  @override
  String toString() {
    return '''
[i2pcontrol]
enabled = $enabled
address = $address
port = $port
password = $_password
''';
  }
}

/// i2pd.conf [precomputation] config
class I2pdPrecomputationConf {
  I2pdPrecomputationConf({this.elgamal});

  /// Enable or disable elgamal precomputation table
  /// By default, enabled on i386 hosts
  bool? elgamal;

  @override
  String toString() {
    return '''
[precomputation]
${elgamal == null ? '#' : ''}elgamal = $elgamal
''';
  }
}

/// i2pd.conf [upnp] config
class I2pdUpnpConf {
  I2pdUpnpConf({
    this.enabled = false,
    this.name = "I2Pd",
  });

  /// Enable or disable UPnP: automatic port forwarding (enabled by default in WINDOWS, ANDROID)
  bool enabled = false;

  /// Name i2pd appears in UPnP forwardings list (default = I2Pd)
  String name = "I2Pd";

  @override
  String toString() {
    return '''
[upnp]
enabled = $enabled
name = $name
''';
  }
}

/// i2pd.conf [meshnets] config
class I2pdMeshnetsConf {
  I2pdMeshnetsConf({
    this.yggdrasil = false,
    this.yggaddress,
  });

  /// Enable connectivity over the Yggdrasil network  (default = false)
  bool yggdrasil = false;

  /// You can bind address from your Yggdrasil subnet 300::/64
  /// The address must first be added to the network interface
  String? yggaddress;
  @override
  String toString() {
    return '''
[meshnets]
yggdrasil = $yggdrasil
${yggaddress == null ? '#' : ''}yggaddress = $yggaddress
''';
  }
}

/// i2pd.conf [reseed] config
class I2pdReseedConf {
  I2pdReseedConf({
    this.verify = true,
    this.urls = const [],
    this.yggurls = const [],
    this.file,
    this.zipfile,
    this.proxy,
    this.threshold = 25,
  });

  /// Options for bootstrapping into I2P network, aka reseeding
  /// Enable reseed data verification (default = true)
  bool verify = true;

  /// URLs to request reseed data from, separated by comma
  /// Default: "mainline" I2P Network reseeds
  List<String> urls = [];

  /// Reseed URLs through the Yggdrasil
  /// for example: http://[324:9de3:fea4:f6ac::ace]:7070/
  List<String> yggurls = [];

  /// Path to local reseed data file (.su3) for manual reseeding
  /// file = /path/to/i2pseeds.su3
  /// or HTTPS URL to reseed from
  /// file = https://legit-website.com/i2pseeds.su3
  String? file;

  /// Path to local ZIP file or HTTPS URL to reseed from
  String? zipfile;

  /// If you run i2pd behind a proxy server, set proxy server for reseeding here
  /// Should be http://address:port or socks://address:port
  String? proxy;

  /// Minimum number of known routers, below which i2pd triggers reseeding (default = 25)
  int threshold = 25;

  @override
  String toString() {
    return '''

[reseed]
verify = $verify
${urls.isEmpty ? '#' : ''} urls = ${urls.join(",")}
${yggurls.isEmpty ? '#' : ''} yggurls = ${yggurls.join(",")}
${file == null ? '#' : ''}file = $file
${zipfile == null ? '#' : ''}zipfile = $zipfile
${proxy == null ? '#' : ''}proxy = $proxy
threshold = $threshold
''';
  }
}

/// i2pd.conf [addressbook] config
class I2pdAddressbookConf {
  I2pdAddressbookConf({
    this.defaulturl = const [],
    this.subscriptions = const [],
  });

  /// AddressBook subscription URL for initial setup
  /// Default: reg.i2p at "mainline" I2P Network
  /// http://shx5vqsw7usdaunyzr2qmes2fq37oumybpudrd4jjj4e4vk4uusa.b32.i2p/hosts.txt
  List<String> defaulturl = [];

  /// Optional subscriptions URLs
  /// http://reg.i2p/hosts.txt,
  /// http://identiguy.i2p/hosts.txt,
  /// http://stats.i2p/cgi-bin/newhosts.txt,
  /// http://rus.i2p/hosts.txt
  List<String> subscriptions = [];

  @override
  String toString() {
    return '''
[addressbook]
${defaulturl.isEmpty ? '#' : ''} defaulturl = $defaulturl
${subscriptions.isEmpty ? '#' : ''} subscriptions = $subscriptions
''';
  }
}

/// i2pd.conf [limits] config
class I2pdLimitsConf {
  I2pdLimitsConf({
    this.transittunnels = 5000,
    this.openfiles = 0,
    this.coresize = 0,
  });

  /// Maximum active transit sessions (default = 5000)
  /// This value is doubled if floodfill mode is enabled!
  int transittunnels = 5000;

  /// Limit number of open file descriptors (0 - use system limit)
  int openfiles = 0;

  /// Maximum size of corefile in Kb (0 - use system limit)
  int coresize = 0;

  @override
  String toString() {
    return '''
[limits]
transittunnels = $transittunnels
openfiles = $openfiles
coresize = $coresize
''';
  }
}

/// i2pd.conf [trust] config
class I2pdTrustConf {
  I2pdTrustConf({
    this.enabled = false,
    this.family,
    this.routers = const [],
    this.hidden = false,
  });

  /// Enable explicit trust options. (default: false)
  bool enabled = false;

  /// Make direct I2P connections only to routers in specified Family.
  String? family;
// Make direct I2P connections only to routers specified here. Comma separated list of base64 identities.
  List<String> routers = [];

  /// Should we hide our router from other routers? (default = false)
  bool hidden = false;

  @override
  String toString() {
    return '''
[trust]
enabled = true
${family == null ? '#' : ''}family = $family
${routers.isEmpty ? '#' : ''}routers = ${routers.join(",")}
hidden = true
''';
  }
}

/// i2pd.conf [exploratory] config
class I2pdExploratoryConf {
  I2pdExploratoryConf({
    this.inboundLength = 2,
    this.inboundQuantity = 3,
    this.outboundLength = 2,
    this.outboundQuantity = 3,
  });

  /// Exploratory tunnels settings with default values
  int inboundLength = 2;

  /// Exploratory tunnels settings with default values
  int inboundQuantity = 3;

  /// Exploratory tunnels settings with default values
  int outboundLength = 2;

  /// Exploratory tunnels settings with default values
  int outboundQuantity = 3;

  @override
  String toString() {
    return '''
[exploratory]
inbound.length = $inboundLength
inbound.quantity = $inboundQuantity
outbound.length = $outboundLength
outbound.quantity = $outboundQuantity
''';
  }
}

/// i2pd.conf [persist] config
class I2pdPersistConf {
  I2pdPersistConf({
    this.profiles = true,
    this.addressbook = true,
  });

  /// Save peer profiles on disk (default = true)
  bool profiles = true;

  /// Save full addresses on disk (default = true)
  bool addressbook = true;

  @override
  String toString() {
    return '''
[persist]
profiles = $profiles
addressbook = $addressbook
''';
  }
}

/// i2pd.conf [cpuext] config
class I2pdCpuextConf {
  I2pdCpuextConf({
    this.aesni = true,
    this.force = false,
  });

  /// Use CPU AES-NI instructions set when work with cryptography when available (default = true)
  bool aesni = true;

  /// Force usage of CPU instructions set, even if they not found (default = false)
  /// DO NOT TOUCH that option if you really don't know what are you doing!
  bool force = false;
  @override
  String toString() {
    return '''
[cpuext]
aesni = $aesni
force = $force
''';
  }
}

abstract class I2pdTunnel {
  I2pdTunnel({required this.name});

  /// Tunnel name - purerly for your information.
  String name;
  static int tunnelSignatureTypeID(TunnelSignatureType type) => switch (type) {
        TunnelSignatureType.dsaSha1 => 0,
        TunnelSignatureType.ecdsaP256 => 1,
        TunnelSignatureType.ecdsaP384 => 2,
        TunnelSignatureType.ecdsaP521 => 3,
        TunnelSignatureType.rsa2048sha256 => 4,
        TunnelSignatureType.rsa3072sha384 => 5,
        TunnelSignatureType.rsa4096sha512 => 6,
        TunnelSignatureType.ed25519sha512 || TunnelSignatureType.auto => 7,
        TunnelSignatureType.ed25519phSha512 => 8,
        TunnelSignatureType.gostr3410aGostr3411_256 => 9,
        TunnelSignatureType.gostr3410Tc26aGostr3411_512 => 10,
        TunnelSignatureType.red25519Sha512 => 11,
      };

  @override
  String toString();
}

/// client 	Client tunnel to remote I2P destination (TCP)
class I2pdClientTunnel implements I2pdTunnel {
  static String get type => "client";

  /// client 	Client tunnel to remote I2P destination (TCP)
  I2pdClientTunnel({
    required this.name,
    required this.address,
    required this.port,
    required this.keys,
    this.signaturetype = TunnelSignatureType.auto,
    this.cryptotype = 0,
    this.destinationport = 0,
    this.keepaliveinterval = 0,
  });
  @override
  String name;

  /// Local interface tunnel binds to, '127.0.0.1' for connections from local host only, '0.0.0.0' for connections from everywhere. (default: 127.0.0.1)
  String address;

  /// Port of client tunnel.
  int port;

  /// Signature type for new keys. RSA signatures (4,5,6) are not allowed and will be changed to 7. (default: 7)
  TunnelSignatureType signaturetype;

  /// Crypto type for new keys. Experimental. Should be always 0
  int cryptotype = 0;

  /// Connect to particular port at destination. 0 by default (targeting first tunnel on server side for destination)
  int destinationport = 0;

  /// Send ping to the destination after this interval in seconds. (default: 0 - no pings)
  int keepaliveinterval = 0;

  /// Keys for destination. When same for several tunnels, will be using same destination for every tunnel.
  String keys;
  @override
  String toString() {
    return '''
[$name]
type = $type
address = $address
port = $port
signaturetype = ${I2pdTunnel.tunnelSignatureTypeID(signaturetype)}
cryptotype = $cryptotype
destinationport = $destinationport
keepaliveinterval = $keepaliveinterval
keys = keys/$keys
''';
  }
}

/// server 	Generic server tunnel to setup any TCP service in I2P network
class I2pdServerTunnel implements I2pdTunnel {
  static String get type => "server";

  /// server 	Generic server tunnel to setup any TCP service in I2P network
  I2pdServerTunnel({
    required this.name,
    required this.host,
    required this.port,
    required this.inport,
    required this.keys,
    this.accesslist = const [],
    this.gzip = false,
    this.signaturetype = TunnelSignatureType.auto,
    this.enableuniquelocal = true,
    this.address,
  });
  @override
  String name;

  /// IP address of server (on this address i2pd will send data from I2P)
  String host;

  /// Port of server tunnel.
  int port;

  /// (non-TCP non-UDP) I2P local destination port to listen to; an unsigned 16-bit integer. What port at local destination server tunnel listens to (default: same as port)
  late int inport = port;

  /// List of comma-separated of b32 address (without .b32.i2p) allowed to connect. Everybody is allowed by default
  List<String> accesslist = [];

  /// Turns internal compression off if set to false. (default: false)
  bool gzip = false;

  /// Signature type for new keys. (default: 7)
  TunnelSignatureType signaturetype = TunnelSignatureType.auto;

  /// Crypto type for new keys. Experimental. Should be always 0
  int cryptotype = 0;

  /// If true, connection to local address will look like 127.x.x.x where x.x.x is first 3 bytes of incoming connection peer's ident hash. (default: true)
  bool enableuniquelocal = true;

  /// IP address of an interface tunnel is connected to host from. Usually not used
  String? address;

  /// Keys for destination. When same for several tunnels, will be using same destination for every tunnel.
  String keys;

  @override
  String toString() {
    return '''
[$name]
type = $type
host = $host
port = $port
inport = $inport
accesslist = $accesslist
gzip = $gzip
signaturetype = ${I2pdTunnel.tunnelSignatureTypeID(signaturetype)}
cryptotype = $cryptotype
enableuniquelocal = $enableuniquelocal
${address == null ? '#' : ''}address = $address
keys = keys/$keys
''';
  }
}

/// http 	HTTP server tunnel to setup a website in I2P
class I2pdHttpTunnel implements I2pdTunnel {
  static String get type => "http";

  /// http 	HTTP server tunnel to setup a website in I2P
  I2pdHttpTunnel({
    required this.name,
    required this.host,
    required this.port,
    required this.inport,
    required this.keys,
    this.accesslist = const [],
    this.gzip = false,
    this.signaturetype = TunnelSignatureType.auto,
    this.enableuniquelocal = true,
    this.address,
  });
  @override
  String name;

  /// IP address of server (on this address i2pd will send data from I2P)
  String host;

  /// Port of server tunnel.
  int port;

  /// (non-TCP non-UDP) I2P local destination port to listen to; an unsigned 16-bit integer. What port at local destination server tunnel listens to (default: same as port)
  late int inport = port;

  /// List of comma-separated of b32 address (without .b32.i2p) allowed to connect. Everybody is allowed by default
  List<String> accesslist = [];

  /// Turns internal compression off if set to false. (default: false)
  bool gzip = false;

  /// Signature type for new keys. (default: 7)
  TunnelSignatureType signaturetype = TunnelSignatureType.auto;

  /// Crypto type for new keys. Experimental. Should be always 0
  int cryptotype = 0;

  /// If true, connection to local address will look like 127.x.x.x where x.x.x is first 3 bytes of incoming connection peer's ident hash. (default: true)
  bool enableuniquelocal = true;

  /// IP address of an interface tunnel is connected to host from. Usually not used
  String? address;

  /// Keys for destination. When same for several tunnels, will be using same destination for every tunnel.
  String keys;

  /// Value to send in 'Host:' header, default: the same as host parameter
  String? hostoverride;

  /// Use SSL connection to upstream server. `hostoverride` parameter can be used to set SNI domain. default: false (since 2.44.0)
  bool ssl = false;

  @override
  String toString() {
    return '''
[$name]
type = $type
host = $host
port = $port
inport = $inport
accesslist = $accesslist
gzip = $gzip
signaturetype = ${I2pdTunnel.tunnelSignatureTypeID(signaturetype)}
cryptotype = $cryptotype
enableuniquelocal = $enableuniquelocal
${address == null ? '#' : ''}address = $address
keys = keys/$keys
${hostoverride == null ? '#' : ''}hostoverride = $hostoverride
ssl = $ssl
''';
  }
}

/// irc 	IRC server tunnel to setup IRC server in I2P
/// IRC tunnels are supposed to connect to an IRC server through WEBIRC. It replaces IP address (usually 127.0.0.1) to user's .b32 I2P address.
class I2pdIrcTunnel implements I2pdTunnel {
  static String get type => "irc";

  /// irc 	IRC server tunnel to setup IRC server in I2P
  /// IRC tunnels are supposed to connect to an IRC server through WEBIRC. It replaces IP address (usually 127.0.0.1) to user's .b32 I2P address.
  I2pdIrcTunnel({
    required this.name,
    required this.host,
    required this.port,
    required this.inport,
    required this.keys,
    this.webircpassword,
    this.accesslist = const [],
    this.gzip = false,
    this.signaturetype = TunnelSignatureType.auto,
    this.enableuniquelocal = true,
    this.address,
  });
  @override
  String name;

  /// IP address of server (on this address i2pd will send data from I2P)
  String host;

  /// Port of server tunnel.
  int port;

  /// (non-TCP non-UDP) I2P local destination port to listen to; an unsigned 16-bit integer. What port at local destination server tunnel listens to (default: same as port)
  late int inport = port;

  /// List of comma-separated of b32 address (without .b32.i2p) allowed to connect. Everybody is allowed by default
  List<String> accesslist = [];

  /// Turns internal compression off if set to false. (default: false)
  bool gzip = false;

  /// Signature type for new keys. (default: 7)
  TunnelSignatureType signaturetype = TunnelSignatureType.auto;

  /// Crypto type for new keys. Experimental. Should be always 0
  int cryptotype = 0;

  /// If true, connection to local address will look like 127.x.x.x where x.x.x is first 3 bytes of incoming connection peer's ident hash. (default: true)
  bool enableuniquelocal = true;

  /// IP address of an interface tunnel is connected to host from. Usually not used
  String? address;

  /// Keys for destination. When same for several tunnels, will be using same destination for every tunnel.
  String keys;

  String? webircpassword;

  @override
  String toString() {
    return '''
[$name]
type = $type
host = $host
port = $port
inport = $inport
accesslist = $accesslist
gzip = $gzip
signaturetype = ${I2pdTunnel.tunnelSignatureTypeID(signaturetype)}
cryptotype = $cryptotype
enableuniquelocal = $enableuniquelocal
${address == null ? '#' : ''}address = $address
keys = keys/$keys
${webircpassword == null ? '#' : ''}webircpassword = $webircpassword
''';
  }
}

/// udpclient 	Forwards local UDP endpoint to remote I2P destination
class I2pdUdpclientTunnel implements I2pdTunnel {
  static String get type => "udpclient";

  /// udpclient 	Forwards local UDP endpoint to remote I2P destination
  I2pdUdpclientTunnel({
    required this.name,
    required this.destination,
    this.address = "127.0.0.1",
    required this.port,
    this.gzip = false,
    required this.keys,
  });
  @override
  String name;

  /// The I2P destination of a udpserver tunnel, required parameter
  String destination;

  /// IP address to bind local UDP endpoint to (default: 127.0.0.1)
  String address = "127.0.0.1";

  /// Port to bind local UDP endpoint to, required parameter
  int port;

  /// Turns internal compression off if set to false. (default: false)
  bool gzip = false;

  /// Keys for destination. When same for several tunnels, will be using same destination for every tunnel.
  String keys;

  @override
  String toString() {
    return '''
[$name]
type = $type
destination = $destination
address = $address
port = $port
gzip = $gzip
keys = keys/$keys
''';
  }
}

/// udpserver 	Forwards traffic from N I2P destinations to local UDP endpoint
class I2pdUdpserverTunnel implements I2pdTunnel {
  static String get type => "udpserver";

  /// udpserver 	Forwards traffic from N I2P destinations to local UDP endpoint
  I2pdUdpserverTunnel({
    required this.name,
    this.address = "127.0.0.1",
    required this.host,
    required this.port,
    this.gzip = false,
    required this.keys,
  });
  @override
  String name;

  /// IP address to use for local UDP endpoints (default: 127.0.0.1)
  String address = "127.0.0.1";

  /// IP address to forward traffic to, required parameter
  String host;

  /// UDP port to forward traffic on, required parameter
  int port;

  /// Turns internal compression off if set to false. (default: false)
  bool gzip = false;

  /// Keys for destination. When same for several tunnels, will be using same destination for every tunnel.
  String keys;
  @override
  String toString() {
    return '''
[$name]
type = $type
address = $address
host = $host
port = $port
gzip = $gzip
keys = keys/$keys
''';
  }
}

/// socks 	Custom Socks proxy service to use I2P with
class I2pdSocksTunnel implements I2pdTunnel {
  static String get type => "socks";

  /// socks 	Custom Socks proxy service to use I2P with
  I2pdSocksTunnel({
    required this.name,
    this.address = "127.0.0.1",
    required this.port,
    required this.keys,
  });
  @override
  String name;

  /// Local address Socks proxy binds to (default: 127.0.0.1)
  String address = "127.0.0.1";

  /// TCP port Socks proxy binds to
  int port;

  /// keys - probably same purpose as the rest
  String keys;

  @override
  String toString() {
    return '''
[$name]
type = $type
address = $address
port = $port
keys = keys/$keys
''';
  }
}

/// It is recommended to use TunnelSignatureType.auto
enum TunnelSignatureType {
  /// DSA-SHA1 	0 	Deprecated
  @Deprecated("Deprecated by i2pd")
  dsaSha1,

  /// ECDSA-P256 	1 	None, actively used
  ecdsaP256,

  /// ECDSA-P384 	2 	None, actively used
  ecdsaP384,

  /// ECDSA-P521 	3 	None, actively used
  ecdsaP521,

  /// RSA-2048-SHA256 	4 	Deprecated
  @Deprecated("Deprecated by i2pd")
  rsa2048sha256,

  /// RSA-3072-SHA384 	5 	Deprecated
  @Deprecated("Deprecated by i2pd")
  rsa3072sha384,

  /// RSA-4096-SHA512 	6 	Deprecated
  @Deprecated("Deprecated by i2pd")
  rsa4096sha512,

  /// ED25519-SHA512 	7 	Default
  ed25519sha512,

  /// ED25519ph-SHA512 	8 	Not implemented
  @Deprecated("Not implemented by i2pd")
  ed25519phSha512,

  /// GOSTR3410-A-GOSTR3411-256 	9 	Not compatible with Java router
  @Deprecated("Not compatible with Java router")
  gostr3410aGostr3411_256,

  /// GOSTR3410-TC26-A-GOSTR3411-512 	10 	Not compatible with Java router
  @Deprecated("Not compatible with Java router")
  gostr3410Tc26aGostr3411_512,

  /// RED25519-SHA512 	11 	For keys blinding (encrypted LeaseSet)
  red25519Sha512,

  /// Pick automatically (recommended)
  auto,
}
