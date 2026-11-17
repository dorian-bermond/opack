// Imports One Piece Card Game booster sets from onepiece.gg (api.dotgg.gg)
// into:
//   assets/sets/opc/<CODE>.json     one file per booster set (OP, EB, PRB)
//
//   dart run tool/import_opc.dart            # every booster set
//   dart run tool/import_opc.dart OP18 EB05  # only these sets
//
// One call lists every card with its details; the base print of each card
// of a booster set is kept (alternate arts and other languages are left
// out). The source gives no pull rates, so the booster formula is derived
// from the rarities present and marked approximate: 12 cards, 7 commons,
// 2 uncommons, 2 rares and a top slot.

import 'dart:convert';
import 'dart:io';

import 'src/common.dart';
import 'src/opc.dart';

final _http = CachedHttp('.cache/opc', delay: const Duration(milliseconds: 300));

Future<void> main(List<String> arguments) async {
  try {
    final body = await _http.get(Uri.https('api.dotgg.gg', '/cgfw/getcards', {'game': 'onepiece', 'mode': 'indexed'}));
    final json = jsonDecode(body ?? '{}') as Map<String, dynamic>;
    final names = (json['names'] as List).cast<String>();
    // Set names from the CardSets column of any of the set's rows.
    final setNames = <String, String>{};
    final (set, cardSets, language) = (names.indexOf('set'), names.indexOf('CardSets'), names.indexOf('language'));
    for (final r in (json['data'] as List).cast<List>()) {
      if (r[language] != 'en') continue;
      final code = opcSetCode('${r[set]}');
      if (r[cardSets] case final String s when s.isNotEmpty) {
        final name = _setName(s);
        // A name that is only the code again is no name.
        if (name.isNotEmpty && name.replaceAll('-', '').toUpperCase() != code) setNames.putIfAbsent(code, () => name);
      }
    }
    final wanted = arguments.map(opcSetCode).toSet();
    var written = 0;
    final bySet = opcCardsBySet(json);
    for (final code in bySet.keys.toList()..sort()) {
      if (wanted.isNotEmpty && !wanted.contains(code)) continue;
      final cards = bySet[code]!;
      if (cards.length < 20) {
        stderr.writeln('Skipping $code: ${cards.length} cards');
        continue;
      }
      final file = buildOpcSet(code, _knownNames[code] ?? setNames[code] ?? code, cards);
      await writeSet(file);
      written++;
      stdout.writeln('$code ${file['names']}: ${(file['cards'] as List).length} cards');
    }
    stdout.writeln('Wrote $written sets');
    await rebuildIndex();
  } finally {
    _http.close();
  }
}

/// Names the source leaves empty or wrong.
const _knownNames = {'OP05': 'Awakening of the New Era'};

/// `BOOSTER PACK -THE DOMINANCE OF GOD- [OP-18]` -> `The Dominance of God`.
String _setName(String cardSets) {
  var name = cardSets
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"').replaceAll(RegExp(r'\s*\[[^\]]*\]\s*$'), '').trim();
  name = name.replaceAll(RegExp(r'^(BOOSTER PACK|EXTRA BOOSTER|PREMIUM BOOSTER|STARTER DECK)\s*', caseSensitive: false), '');
  name = name.replaceAll(RegExp(r'^-+|-+$'), '').trim();
  const small = {'of', 'the', 'in', 'a', 'an', 'and', 'on', 'to', 'vs'};
  final words = name.toLowerCase().split(RegExp(r'\s+'));
  return [
    for (final (i, w) in words.indexed)
      if (w.isEmpty || (i > 0 && small.contains(w))) w else w[0].toUpperCase() + w.substring(1),
  ].join(' ');
}
