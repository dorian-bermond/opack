import 'dart:convert';
import 'dart:typed_data';

import 'play_pool.dart';
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

/// The file name a pool's card list exports under.
String poolCardListFileName(Pool pool) => poolFileName(pool).replaceFirst(RegExp(r'\.opack\.json$'), '.txt');

/// The pool's cards as a plain list, one per line as `3 Name`, in
/// [language] where a card has that name (else English), sorted by name:
/// what any deck tool reads, the batch import included. The number is the
/// card's copies in the pool; a card with unlimited copies counts once,
/// one left out of the pool (no copy) is not listed.
String poolCardList(PlayPool play, String language) {
  final lines = <(String, int)>[];
  for (final (:card, :listed) in play.entries) {
    final copies = play.pool.copiesOf(card.id, listed: listed);
    if (copies == 0) continue;
    lines.add((card.nameFor(language), copies ?? 1));
  }
  lines.sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
  return [for (final (name, copies) in lines) '$copies $name', ''].join('\n');
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
