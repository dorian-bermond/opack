// Pure helpers turning optcgapi.com answers into One Piece set files, kept
// apart from the network code so tests can cover them.

/// The app's rarity for an optcgapi rarity code.
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

/// `OP-01` as the app's set code, `OP01`.
String opcSetCode(String setId) => setId.replaceAll('-', '').toUpperCase();

/// Whether a set is sold in random boosters (the ones the app simulates):
/// main boosters (OP), extra boosters (EB) and premium boosters (PRB);
/// starter decks (ST) and promos are left out.
bool opcIsBooster(String setId) => RegExp(r'^(OP|EB|PRB)-?\d+$', caseSensitive: false).hasMatch(setId);

/// Relative odds of the pack's top slot: a super rare most often, a
/// leader about one pack in three, a secret rare or a special one rarely.
const opcTopSlotWeights = {'superRare': 12, 'leader': 6, 'secretRare': 1, 'special': 1};

/// A set file from the API's card list: the cards once each (the API
/// repeats a card per printing), with a 12-card booster formula drawn
/// from the rarities present, marked approximate.
Map<String, Object?> buildOpcSet(String setId, String setName, List<Map<String, dynamic>> apiCards) {
  final seen = <String>{};
  final cards = <Map<String, Object?>>[];
  for (final c in apiCards) {
    final id = (c['card_set_id'] as String? ?? '').trim();
    if (id.isEmpty || !seen.add(id)) continue;
    cards.add({
      'id': id,
      'names': {'en': (c['card_name'] as String? ?? '').trim()},
      'rarity': opcRarity(c['rarity'] as String?),
    });
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

  return {
    'code': opcSetCode(setId),
    'prefix': opcSetCode(setId),
    'game': 'opc',
    'names': {'en': setName},
    'source': 'https://optcgapi.com/api/sets/$setId/',
    'license': 'Card data from optcgapi.com. ONE PIECE CARD GAME is © Eiichiro Oda / Shueisha, Bandai.',
    'boosters': {
      'standard': {'approximate': true, 'variants': variants, 'sheets': sheets},
    },
    'cards': cards,
  };
}
