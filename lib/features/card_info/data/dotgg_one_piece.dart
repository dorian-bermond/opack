import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// onepiece.gg's card list (api.dotgg.gg): every One Piece card, every
/// language and alternate art, as rows under a shared list of column
/// names. Loaded once per run and kept.
class DotggOnePiece {
  static final endpoint = Uri.https('api.dotgg.gg', '/cgfw/getcards', {'game': 'onepiece', 'mode': 'indexed'});

  static const headers = {'User-Agent': 'Opack/1.0', 'Accept': 'application/json'};

  static List<Map<String, Object?>>? _rows;

  /// The English rows, base prints and alternate arts alike.
  static Future<List<Map<String, Object?>>> rows(http.Client client) async {
    if (_rows case final rows?) return rows;
    final response = await client.get(endpoint, headers: headers);
    if (response.statusCode != 200) throw HttpException('onepiece.gg ${response.statusCode}');
    return _rows = parse(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  /// Forgets the loaded list (tests).
  static void reset() => _rows = null;

  /// The English rows of an indexed answer (`names` + `data`).
  static List<Map<String, Object?>> parse(Map<String, dynamic> json) {
    final names = (json['names'] as List).cast<String>();
    final rows = <Map<String, Object?>>[];
    for (final values in (json['data'] as List).cast<List>()) {
      final row = {for (final (i, name) in names.indexed) name: i < values.length ? values[i] : null};
      if (row['language'] == 'en') rows.add(row);
    }
    return rows;
  }

  /// The base print's code of a row: `OP01-001` for the alt art `OP01-001_p1`.
  static String baseId(Map<String, Object?> row) => '${row['id_normal'] ?? row['id']}';

  /// Whether the row is the base print (not an alternate art).
  static bool isBase(Map<String, Object?> row) => row['id'] == baseId(row);

  /// The picture of a print, base or alternate, by its dotgg id.
  static Uri image(String id) => Uri.https('static.dotgg.gg', '/onepiece/card/$id.webp');

  /// The set's name from `-ROMANCE DAWN- [OP01]`: title-cased, without
  /// the product prefix and the code.
  static String setName(String cardSets) {
    var name = cardSets.replaceAll(RegExp(r'\s*\[[^\]]*\]\s*$'), '').trim();
    name = name.replaceAll(RegExp(r'^(BOOSTER PACK|EXTRA BOOSTER|PREMIUM BOOSTER|STARTER DECK)\s*', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'^-+|-+$'), '').trim();
    const small = {'of', 'the', 'in', 'a', 'an', 'and', 'on', 'to', 'vs'};
    final words = name.toLowerCase().split(RegExp(r'\s+'));
    return [
      for (final (i, w) in words.indexed)
        if (w.isEmpty)
          w
        else if (i > 0 && small.contains(w))
          w
        else
          w[0].toUpperCase() + w.substring(1),
    ].join(' ');
  }
}
