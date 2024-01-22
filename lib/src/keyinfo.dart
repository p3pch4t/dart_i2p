import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:base32/base32.dart';

void keyinfo(String path) {
  File file = File(path);
  List<int> content = file.readAsBytesSync();

  // Take the first 391 bytes of the file content
  List<int> data = content.sublist(0, 391);

  // Calculate the SHA-256 hash of the data
  Digest sha256Digest = sha256.convert(data);

  // Convert the hash to base32
  String base32Hash = base32.encode(Uint8List.fromList(sha256Digest.bytes));

  // Remove padding characters from base32
  base32Hash = base32Hash.replaceAll('=', '');

  // Convert the base32 hash to lowercase
  base32Hash = base32Hash.toLowerCase();

  // Print the result
  print('$base32Hash.b32.i2p');
}
