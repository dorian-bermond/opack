import 'dart:convert';
import 'dart:typed_data';

import 'pool.dart';

/// A pool as a file: its sources, tags, boosters, formats, copies and
/// artworks under a format mark, the device-bound picture left out.
const poolFileFormat = 'opack-pool';
const poolFileVersion = 1;

/// The file name a pool exports under.
String poolFileName(Pool pool) {
  final stem = pool.name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ').trim();
  return '${stem.isEmpty ? 'pool' : stem}.opack.json';
}

Uint8List encodePool(Pool pool) => utf8.encode(const JsonEncoder.withIndent(' ').convert({
      'format': poolFileFormat,
      'version': poolFileVersion,
      'pool': pool.withCover(null).toJson(),
    }));

/// The pool in [bytes]; a [FormatException] when they are not a pool file.
Pool decodePool(List<int> bytes) {
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const FormatException('not JSON');
  }
  if (json is! Map<String, dynamic> || json['format'] != poolFileFormat || json['pool'] is! Map<String, dynamic>) {
    throw const FormatException('not a pool file');
  }
  try {
    return Pool.fromJson(json['pool'] as Map<String, dynamic>);
  } on Object catch (e) {
    throw FormatException('a broken pool file: $e');
  }
}
