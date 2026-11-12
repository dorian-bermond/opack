// Builds assets/cards/ygo_cards.json: every Yu-Gi-Oh! card with its
// passcode and French/English names, used to resolve cube lists offline.
//
//   dart run tool/import_ygo_cards.dart
//
// Source: YGOPRODeck (https://ygoprodeck.com), English and French databases.

import 'dart:convert';
import 'dart:io';

import 'src/common.dart';

const _api = 'https://db.ygoprodeck.com/api/v7/cardinfo.php';

Future<void> main() async {
  final http = CachedHttp('.cache/ygo');
  try {
    Future<List<Map<String, dynamic>>> load(String query) async {
      final body = await http.get(Uri.parse('$_api$query'));
      return ((jsonDecode(body!) as Map)['data'] as List).cast<Map<String, dynamic>>();
    }

    final french = {for (final card in await load('?language=fr')) card['id']: card['name']};
    final cards = [
      for (final card in await load(''))
        {
          'id': '${card['id']}',
          'names': {'en': card['name'], 'fr': ?french[card['id']]},
          // Alternate artworks share the card: map their passcodes too.
          if ((card['card_images'] as List?)
                  ?.map((i) => '${i['id']}')
                  .where((id) => id != '${card['id']}')
                  .toList()
              case final List<String> alts when alts.isNotEmpty)
            'alt': alts,
        },
    ];

    final file = File('assets/cards/ygo_cards.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(cards));
    final fr = cards.where((c) => (c['names'] as Map).containsKey('fr')).length;
    stdout.writeln('Wrote ${cards.length} cards ($fr with French names) to ${file.path}');
  } finally {
    http.close();
  }
}
