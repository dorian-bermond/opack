// Pure helpers turning onepiece.gg (api.dotgg.gg) rows into One Piece set
// files, kept apart from the network code so tests can cover them.

/// The app's rarity for a One Piece rarity code.
String opcRarity(String? code) => switch ((code ?? '').trim().toUpperCase()) {
      'C' => 'common',
      'UC' => 'uncommon',
      'R' => 'rare',
      'SR' => 'superRare',
      'L' => 'leader',
      'SEC' => 'secretRare',
      'TR' => 'secretRare',
      _ => 'special',
    };

/// A set code as the app uses it, without hyphen: `OP-01` -> `OP01`.
String opcSetCode(String setId) => setId.replaceAll('-', '').toUpperCase();

/// Whether a set is sold in random boosters (the ones the app simulates):
/// main boosters (OP), extra boosters (EB) and premium boosters (PRB);
/// starter decks (ST) and promos are left out.
bool opcIsBooster(String setId) => RegExp(r'^(OP|EB|PRB)\d+$', caseSensitive: false).hasMatch(opcSetCode(setId));

/// Relative odds of the pack's top slot: a super rare most often, a
/// leader about one pack in three, a secret rare or a special one rarely.
const opcTopSlotWeights = {'superRare': 12, 'leader': 6, 'secretRare': 1, 'special': 1};

/// One card as the set builder needs it.
typedef OpcCard = ({String id, String name, String rarityCode});

/// The English rows of a dotgg indexed answer that are base prints of a
/// booster set, as [OpcCard]s by set code.
Map<String, List<OpcCard>> opcCardsBySet(Map<String, dynamic> json) {
  final names = (json['names'] as List).cast<String>();
  int col(String n) => names.indexOf(n);
  final (id, idNormal, rarity, name, set, language, type) =
      (col('id'), col('id_normal'), col('rarity'), col('name'), col('set'), col('language'), col('cardType'));
  final bySet = <String, List<OpcCard>>{};
  for (final r in (json['data'] as List).cast<List>()) {
    if (r[language] != 'en' || r[id] != r[idNormal] || r[type] == 'DON') continue;
    final code = opcSetCode('${r[set]}');
    if (!opcIsBooster(code)) continue;
    (bySet[code] ??= []).add((id: '${r[id]}', name: '${r[name]}', rarityCode: '${r[rarity]}'));
  }
  return bySet;
}

/// A set file: the cards once each, with a 12-card booster formula drawn
/// from the rarities present, marked approximate.
Map<String, Object?> buildOpcSet(String code, String setName, List<OpcCard> input) {
  final seen = <String>{};
  final cards = <Map<String, Object?>>[];
  for (final c in input) {
    if (c.id.isEmpty || !seen.add(c.id)) continue;
    cards.add({'id': c.id, 'names': {'en': c.name.trim()}, 'rarity': opcRarity(c.rarityCode)});
  }
  cards.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  final byRarity = <String, List<int>>{};
  for (final (i, card) in cards.indexed) {
    (byRarity[card['rarity'] as String] ??= []).add(i);
  }
  final sheets = {
    for (final MapEntry(key: rarity, value: indexes) in byRarity.entries)
      rarity: {'cards': [for (final i in indexes) [i, 1]]},
  };
  // 11 cards from the common sheets, 1 from the top slot.
  final base = <String, int>{
    if (byRarity.containsKey('common')) 'common': 7,
    if (byRarity.containsKey('uncommon')) 'uncommon': 2,
    if (byRarity.containsKey('rare')) 'rare': 2,
  };
  final variants = [
    for (final MapEntry(key: top, value: weight) in opcTopSlotWeights.entries)
      if (byRarity.containsKey(top)) {'weight': weight, 'contents': {...base, top: 1}},
  ];
  if (variants.isEmpty && base.isNotEmpty) variants.add({'weight': 1, 'contents': base});

  final setCode = opcSetCode(code);
  return {
    'code': setCode,
    'prefix': setCode,
    'game': 'opc',
    'names': {'en': setName},
    'source': 'https://onepiece.gg/',
    'license': 'Card data from onepiece.gg. ONE PIECE CARD GAME is © Eiichiro Oda / Shueisha, Bandai.',
    'boosters': {
      'standard': {'approximate': true, 'variants': variants, 'sheets': sheets},
    },
    'cards': cards,
  };
}
