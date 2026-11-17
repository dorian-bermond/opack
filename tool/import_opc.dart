// Imports One Piece Card Game booster sets from optcgapi.com into:
//   assets/sets/opc/<CODE>.json     one file per booster set (OP, EB, PRB)
//
//   dart run tool/import_opc.dart            # every booster set
//   dart run tool/import_opc.dart OP-01 EB-01 # only these sets
//
// The API lists sets (`/api/allSets/`) and the cards of a set with their
// details and picture (`/api/sets/<id>/`). It gives no pull rates, so the
// booster formula is derived from the rarities present and marked
// approximate: 12 cards, 7 commons, 2 uncommons, 2 rares and a top slot.

import 'dart:convert';
import 'dart:io';

import 'src/common.dart';
import 'src/opc.dart';

const _api = 'https://optcgapi.com/api';

final _http = CachedHttp('.cache/opc', delay: const Duration(milliseconds: 300));

Future<void> main(List<String> arguments) async {
  try {
    final listing = await _http.get(Uri.parse('$_api/allSets/'));
    final sets = (jsonDecode(listing ?? '[]') as List).cast<Map<String, dynamic>>();
    final wanted = arguments.map((a) => a.toUpperCase()).toSet();
    var written = 0;
    for (final set in sets) {
      final id = set['set_id'] as String? ?? '';
      final name = set['set_name'] as String? ?? id;
      if (wanted.isNotEmpty ? !wanted.contains(id.toUpperCase()) : !opcIsBooster(id)) continue;
      final body = await _http.get(Uri.parse('$_api/sets/$id/'));
      if (body == null || body.trim().startsWith('{')) {
        stderr.writeln('No cards for $id');
        continue;
      }
      final cards = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
      final file = buildOpcSet(id, name, cards);
      if ((file['cards'] as List).length < 20) {
        stderr.writeln('Skipping $id: ${(file['cards'] as List).length} cards');
        continue;
      }
      await writeSet(file);
      written++;
      stdout.writeln('$id $name: ${(file['cards'] as List).length} cards');
    }
    stdout.writeln('Wrote $written sets');
    await rebuildIndex();
  } finally {
    _http.close();
  }
}
