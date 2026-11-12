import '../../catalog/domain/models.dart';

const _mtgRarities = {
  'common': Rarity.common,
  'uncommon': Rarity.uncommon,
  'rare': Rarity.rare,
  'mythic': Rarity.mythic,
  'special': Rarity.special,
  'bonus': Rarity.special,
};

/// Reads the mainboard of a CubeCobra `cube/api/cubeJSON/<id>` response.
/// [frenchNames] maps English card names to French ones.
({String name, List<CardData> cards}) parseCubeCobra(
  Map<String, dynamic> json,
  Map<String, String> frenchNames,
) {
  final mainboard = (json['cards'] as Map<String, dynamic>)['mainboard'] as List;
  final cards = <CardData>[];
  for (final entry in mainboard.cast<Map<String, dynamic>>()) {
    final details = entry['details'] as Map<String, dynamic>? ?? const {};
    final name = details['name'] as String?;
    if (name == null) continue;
    cards.add(CardData(
      id: '${(details['set'] as String? ?? '').toUpperCase()}-${details['collector_number'] ?? ''}',
      names: {'en': name, 'fr': ?frenchNames[name]},
      rarity: _mtgRarities[details['rarity']] ?? Rarity.common,
      colors: ((details['colors'] as List?) ?? const []).join(),
      score: (details['elo'] as num?)?.toDouble(),
      scryfallId: details['scryfall_id'] as String?,
    ));
  }
  return (name: json['name'] as String? ?? json['shortId'] as String? ?? '', cards: cards);
}

/// Accepts a CubeCobra link or a bare cube ID.
String cubeCobraId(String input) {
  final trimmed = input.trim();
  final match = RegExp(r'cubecobra\.com/cube/\w+/([^/?#\s]+)').firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

/// Yu-Gi-Oh! card names and passcodes, from `assets/cards/ygo_cards.json`.
class YgoCardDatabase {
  YgoCardDatabase(List<dynamic> json) {
    for (final entry in json.cast<Map<String, dynamic>>()) {
      final names = (entry['names'] as Map<String, dynamic>).cast<String, String>();
      final id = entry['id'] as String;
      final card = CardData(id: id, names: names, rarity: Rarity.common, passcode: id);
      _byPasscode[card.id] = card;
      for (final alt in (entry['alt'] as List? ?? const []).cast<String>()) {
        _byPasscode[alt] = card;
      }
      for (final name in names.values) {
        _byName[normalizeCardName(name)] = card;
      }
    }
  }

  final _byPasscode = <String, CardData>{};
  final _byName = <String, CardData>{};

  CardData? byPasscode(String passcode) =>
      _byPasscode[passcode.replaceFirst(RegExp('^0+'), '')] ?? _byPasscode[passcode];

  CardData? byName(String name) => _byName[normalizeCardName(name)];
}

String normalizeCardName(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('[’`´]'), "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Reads a `.ydk` deck file (passcodes) or a text list with one card name
/// (French or English) per line, optionally prefixed by a count (`3x Name`).
({List<CardData> cards, List<String> unresolved}) parseYgoList(
  String text,
  YgoCardDatabase database,
) {
  final cards = <CardData>[];
  final unresolved = <String>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith('!')) continue;

    CardData? lookup(String value) => RegExp(r'^\d{5,}$').hasMatch(value)
        ? database.byPasscode(value)
        : database.byName(value);

    // The whole line first: some names start with a number ("7 Colored Fish").
    var card = lookup(line);
    var count = 1;
    if (card == null) {
      final counted = RegExp(r'^(\d{1,2})\s*x?\s+(.+)$', caseSensitive: false).firstMatch(line);
      if (counted != null) {
        card = lookup(counted.group(2)!);
        count = int.parse(counted.group(1)!);
      }
    }
    if (card == null) {
      unresolved.add(line);
    } else {
      cards.addAll(List.filled(count, card));
    }
  }
  return (cards: cards, unresolved: unresolved);
}
