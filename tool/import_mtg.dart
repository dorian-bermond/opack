// Imports MtG booster sets into assets/sets/mtg/<CODE>.json.
//
//   dart run tool/import_mtg.dart            # every paper booster set
//   dart run tool/import_mtg.dart DMU MKM    # only these sets
//
// Sources:
// - MTGJSON (https://mtgjson.com, MIT): card lists and booster formulas
//   (weighted pack variants and card sheets).
// - Scryfall (https://scryfall.com): French printed names.
// Downloads are cached in .cache/ so re-runs only fetch what is missing.

import 'dart:convert';
import 'dart:io';

import 'src/common.dart';
import 'src/mtg_icons.dart';

const _mtgjson = 'https://mtgjson.com/api/v5';

/// Set types that are sold in random boosters.
const _boosterSetTypes = {'core', 'expansion', 'masters', 'draft_innovation', 'funny'};

/// MTGJSON booster name -> app booster type. Others (arena, jumpstart,
/// prerelease, box toppers, samples) are not imported.
const _boosterTypes = {
  'play': 'play',
  'draft': 'draft',
  'default': 'standard',
  'set': 'set',
  'collector': 'collector',
};

const _rarities = {
  'common': 'common',
  'uncommon': 'uncommon',
  'rare': 'rare',
  'mythic': 'mythic',
  'special': 'special',
  'bonus': 'special',
};

final _http = CachedHttp('.cache/mtg');
final _setFiles = <String, Map<String, dynamic>?>{};
final _frenchNames = <String, Map<String, String>>{};

Future<void> main(List<String> args) async {
  try {
    final setList = jsonDecode((await _http.get(Uri.parse('$_mtgjson/SetList.json')))!)
        as Map<String, dynamic>;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final wanted = args.map((a) => a.toUpperCase()).toSet();
    final codes = [
      for (final set in (setList['data'] as List).cast<Map<String, dynamic>>())
        if (wanted.isEmpty
            ? _boosterSetTypes.contains(set['type']) &&
                set['isOnlineOnly'] != true &&
                (set['releaseDate'] as String).compareTo(today) <= 0
            : wanted.contains(set['code']))
          set['code'] as String,
    ];

    var written = 0;
    for (final code in codes) {
      try {
        if (await _importSet(code)) written++;
      } catch (e) {
        stderr.writeln('$code: failed ($e)');
      }
    }
    stdout.writeln('Wrote $written of ${codes.length} sets');
    await importMtgIcons(_http);
    await rebuildIndex();
  } finally {
    _http.close();
  }
}

Future<bool> _importSet(String code) async {
  final data = await _setFile(code);
  final boosters = (data?['booster'] as Map<String, dynamic>?) ?? {};
  final kept = {
    for (final MapEntry(:key, :value) in boosters.entries)
      ?_boosterTypes[key]: value as Map<String, dynamic>,
  };
  if (data == null || kept.isEmpty) {
    stdout.writeln('$code: no paper booster, skipped');
    return false;
  }

  // Index every card the kept boosters can contain, across source sets.
  final byUuid = <String, Map<String, dynamic>>{};
  final sources = {
    code,
    for (final booster in kept.values) ...(booster['sourceSetCodes'] as List? ?? []).cast<String>(),
  };
  for (final source in sources) {
    final file = source == code ? data : await _setFile(source);
    for (final card in [...?file?['cards'] as List?, ...?file?['tokens'] as List?]) {
      byUuid[card['uuid'] as String] = card as Map<String, dynamic>;
    }
  }

  final cards = <Map<String, Object?>>[];
  final cardIndex = <String, int>{};
  var missing = 0;

  Future<int?> indexOf(String uuid) async {
    if (cardIndex[uuid] case final index?) return index;
    final card = byUuid[uuid];
    if (card == null) {
      missing++;
      return null;
    }
    final setCode = card['setCode'] as String;
    final number = card['number'] as String;
    final french = (await _french(setCode))[number];
    cards.add({
      'id': '$setCode-$number',
      'names': {'en': card['name'], 'fr': ?french},
      'rarity': _rarities[card['rarity']] ?? 'common',
      if ((card['colors'] as List?)?.isNotEmpty ?? false)
        'colors': (card['colors'] as List).join(),
      if (card['identifiers']?['scryfallId'] case final String scryfallId)
        'scryfallId': scryfallId,
    });
    return cardIndex[uuid] = cards.length - 1;
  }

  final formulas = <String, Object?>{};
  for (final MapEntry(key: type, value: booster) in kept.entries) {
    final sheets = <String, Object?>{};
    for (final MapEntry(key: name, value: sheet)
        in (booster['sheets'] as Map<String, dynamic>).entries) {
      final entries = <List<int>>[];
      for (final MapEntry(key: uuid, value: weight)
          in (sheet['cards'] as Map<String, dynamic>).entries) {
        if (await indexOf(uuid) case final index?) entries.add([index, weight as int]);
      }
      if (entries.isEmpty) continue;
      sheets[name] = {
        'cards': entries,
        if (sheet['foil'] == true) 'foil': true,
        if (sheet['balanceColors'] == true) 'balanceColors': true,
        if (sheet['allowDuplicates'] == true) 'allowDuplicates': true,
      };
    }
    // Drop variants that use a sheet whose cards could not be resolved.
    final variants = [
      for (final variant in (booster['boosters'] as List).cast<Map<String, dynamic>>())
        if ((variant['contents'] as Map).keys.every(sheets.containsKey))
          {'weight': variant['weight'], 'contents': variant['contents']},
    ];
    if (variants.isNotEmpty) formulas[type] = {'variants': variants, 'sheets': sheets};
  }
  if (formulas.isEmpty) {
    stdout.writeln('$code: booster cards not found, skipped');
    return false;
  }

  await writeSet({
    'code': code,
    'game': 'mtg',
    'names': {
      'en': data['name'],
      'fr': ?(data['translations'] as Map?)?['French'],
    },
    'releaseDate': data['releaseDate'],
    'license': 'Card data: MTGJSON (MIT) and Scryfall. '
        'Magic: The Gathering is © Wizards of the Coast.',
    'boosters': formulas,
    'cards': cards,
  });
  final frCount = cards.where((c) => (c['names'] as Map).containsKey('fr')).length;
  stdout.writeln('$code: ${cards.length} cards ($frCount in French), '
      'boosters ${formulas.keys.join('/')}'
      '${missing > 0 ? ', $missing unresolved sheet entries' : ''}');
  return true;
}

Future<Map<String, dynamic>?> _setFile(String code) async {
  if (_setFiles.containsKey(code)) return _setFiles[code];
  // MTGJSON suffixes device names reserved on Windows (CON -> CON_).
  final body = await _http.get(Uri.parse('$_mtgjson/${assetFileName(code)}.json.gz'));
  return _setFiles[code] =
      body == null ? null : (jsonDecode(body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;
}

/// French printed names of a set, keyed by collector number.
Future<Map<String, String>> _french(String setCode) async {
  if (_frenchNames[setCode] case final names?) return names;
  final names = <String, String>{};
  Uri? next = Uri.https('api.scryfall.com', '/cards/search', {
    'q': 'e:$setCode lang:fr',
    'unique': 'prints',
    'include_extras': 'true',
    'include_variations': 'true',
  });
  while (next != null) {
    final body = await _http.get(next, headers: {'Accept': 'application/json'});
    if (body == null) break; // 404: no French prints
    final page = jsonDecode(body) as Map<String, dynamic>;
    for (final card in (page['data'] as List).cast<Map<String, dynamic>>()) {
      final faces = (card['card_faces'] as List?)?.cast<Map<String, dynamic>>();
      final name = card['printed_name'] ??
          faces?.map((f) => f['printed_name'] ?? f['name']).join(' // ');
      if (name is String && name.isNotEmpty) names[card['collector_number'] as String] = name;
    }
    next = page['has_more'] == true ? Uri.parse(page['next_page'] as String) : null;
  }
  return _frenchNames[setCode] = names;
}
