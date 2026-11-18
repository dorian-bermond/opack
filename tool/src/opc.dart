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

/// Relative odds of the pack's top slot, per community box-opening data
/// (Bandai publishes none): a plain extra rare most often, a super rare
/// about one pack in three or four (5 to 8 per 24-pack box), a leader
/// about one in four, a secret rare about one per box or two; then the
/// other versions of the set's cards (see [opcVersion]): a parallel art
/// one or two per box, a special art (reprints of other sets' cards in a
/// new art, mostly in extra boosters) one or two per 12-box case, a manga
/// art about one per case, the treasure rare rarer still. Scaled so every
/// weight is whole.
const opcTopSlotWeights = {
  'rare': 250,
  'superRare': 175,
  'leader': 150,
  'secretRare': 18,
  'parallel': 38,
  'special': 3,
  'manga': 2,
  'treasure': 1,
};

/// The booster set a print is pulled from: the product named in its
/// `CardSets` column (`… [EB-05]`) when that is a booster, else its own
/// set column. Extra boosters reprint other sets' cards in a special art
/// that way, keeping the original code (`OP17-081_p1` in EB-05).
String opcPulledFrom(String cardSets, String setColumn) {
  final named = RegExp(r'\[([A-Za-z]+-?\d+)\]\s*$').firstMatch(cardSets);
  if (named != null && opcIsBooster(named.group(1)!)) return opcSetCode(named.group(1)!);
  return opcSetCode(setColumn);
}

/// The version of a print by its code's suffix, as onepiece.gg names
/// them: `''` the base print, `p1`, `p2`… the other arts in order, `r…` a
/// reprint from another product.
String opcVersion(String id) {
  final m = RegExp(r'_([a-z]+\d*)$').firstMatch(id);
  return m == null ? '' : m.group(1)!;
}

/// The booster rarity of an alternate print, the sheet it pulls from in
/// the top slot: `parallel`, `special`, `manga`, `treasure` (its printed
/// rarity kept apart); `null` for the base print, whose sheet is its
/// printed rarity's, and for reprints, which boosters never hold. The
/// version number alone does not tell a manga art (onepiece.gg
/// numbers every art of a card across products), so [manga] says whether
/// a print is one (see `limitless.dart`): otherwise the first art of a
/// card of the [product] itself is its parallel art, and any other art
/// (another product's card in a new art, a second art of the set's own
/// card) a special one.
String? opcVersionSheet(String id, String rarityCode, {String? product, bool manga = false}) {
  final version = opcVersion(id);
  if (version.startsWith('r')) return null;
  final code = rarityCode.trim().toUpperCase();
  if (code == 'TR') return 'treasure';
  if (code == 'SP CARD') return 'special';
  if (manga) return 'manga';
  if (version.isEmpty) return null;
  final own = product == null || id.startsWith('${opcSetCode(product)}-');
  if (own && version == 'p1') return 'parallel';
  return 'special';
}

/// One card as the set builder needs it.
typedef OpcCard = ({String id, String name, String rarityCode});

/// The English rows of a dotgg indexed answer that belong to a booster
/// set, base prints and other versions alike (reprints left out), as
/// [OpcCard]s by set code.
Map<String, List<OpcCard>> opcCardsBySet(Map<String, dynamic> json) {
  final names = (json['names'] as List).cast<String>();
  int col(String n) => names.indexOf(n);
  final (id, rarity, name, set, language, type, cardSets) =
      (col('id'), col('rarity'), col('name'), col('set'), col('language'), col('cardType'), col('CardSets'));
  final bySet = <String, List<OpcCard>>{};
  for (final r in (json['data'] as List).cast<List>()) {
    if (r[language] != 'en' || r[type] == 'DON') continue;
    final code = opcPulledFrom(cardSets < 0 ? '' : '${r[cardSets] ?? ''}', '${r[set]}');
    if (!opcIsBooster(code) || opcVersion('${r[id]}').startsWith('r')) continue;
    (bySet[code] ??= []).add((id: '${r[id]}', name: '${r[name]}', rarityCode: '${r[rarity]}'));
  }
  return bySet;
}

/// A set file: the cards once each, every version a card of its own at
/// its booster rarity (an alternate print keeps its printed rarity in
/// `printedRarity`), with a 12-card booster formula drawn from the
/// rarities present, marked approximate: 7 commons, 2 uncommons, 2 rares
/// and a top slot (see [opcTopSlotWeights]). [manga] names the prints
/// that are manga arts.
Map<String, Object?> buildOpcSet(String code, String setName, List<OpcCard> input, {Set<String> manga = const {}}) {
  final seen = <String>{};
  final cards = <Map<String, Object?>>[];
  final sheetOf = <String, String>{};
  for (final c in input) {
    if (c.id.isEmpty || !seen.add(c.id)) continue;
    final printed = opcRarity(c.rarityCode);
    final rarity = opcVersionSheet(c.id, c.rarityCode, product: code, manga: manga.contains(c.id)) ?? printed;
    cards.add({
      'id': c.id,
      'names': {'en': c.name.trim()},
      'rarity': rarity,
      if (rarity != printed) 'printedRarity': printed,
    });
    sheetOf[c.id] = rarity;
  }
  cards.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  final bySheet = <String, List<int>>{};
  for (final (i, card) in cards.indexed) {
    (bySheet[sheetOf[card['id'] as String]!] ??= []).add(i);
  }
  final sheets = {
    for (final MapEntry(key: sheet, value: indexes) in bySheet.entries)
      sheet: {'cards': [for (final i in indexes) [i, 1]]},
  };
  // 11 cards from the common sheets, 1 from the top slot; extra boosters
  // have no uncommons, their commons and rares fill the pack.
  final uncommons = bySheet.containsKey('uncommon');
  final base = <String, int>{
    if (bySheet.containsKey('common')) 'common': uncommons ? 7 : 8,
    if (uncommons) 'uncommon': 2,
    if (bySheet.containsKey('rare')) 'rare': uncommons ? 2 : 3,
  };
  final variants = [
    for (final MapEntry(key: top, value: weight) in opcTopSlotWeights.entries)
      if (bySheet.containsKey(top))
        {'weight': weight, 'contents': {...base, top: (base[top] ?? 0) + 1}},
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
