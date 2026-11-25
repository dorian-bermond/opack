import '../../card_info/domain/card_info.dart';
import '../../catalog/domain/models.dart';

/// A pool's own values for a card's fields, by field key: the card's own
/// data under `card.…` (`card.name.en`, `card.rarity`, `card.printedRarity`,
/// `card.colors`), its details under the detail's JSON key (`atk`,
/// `manaCost`, `text`…). The base value stays in the set, so a custom
/// field reverts on demand.
typedef CardCustoms = Map<String, Object?>;

const cardFieldPrefix = 'card.';

/// The card-level fields a user may edit, in order.
List<String> cardFieldKeys(CardData card) => [
      for (final lang in {...card.names.keys, 'en', 'fr'}) '${cardFieldPrefix}name.$lang',
      '${cardFieldPrefix}rarity',
      '${cardFieldPrefix}printedRarity',
      '${cardFieldPrefix}colors',
    ];

/// The value of a card-level field on [card].
Object? cardFieldValue(CardData card, String key) {
  final field = key.substring(cardFieldPrefix.length);
  if (field.startsWith('name.')) return card.names[field.substring(5)];
  return switch (field) {
    'rarity' => card.rarity.name,
    'printedRarity' => card.printedRarity?.name,
    'colors' => card.colors,
    _ => null,
  };
}

/// [card] with [customs] applied; foil kept.
CardData customizeCard(CardData card, CardCustoms customs) {
  if (customs.isEmpty) return card;
  final json = card.toJson();
  final names = {...card.names};
  for (final MapEntry(key: key, value: value) in customs.entries) {
    if (!key.startsWith(cardFieldPrefix)) continue;
    final field = key.substring(cardFieldPrefix.length);
    if (field.startsWith('name.')) {
      final lang = field.substring(5);
      if (value == null) {
        names.remove(lang);
      } else {
        names[lang] = '$value';
      }
    } else if (field == 'rarity' && value is String && Rarity.values.any((r) => r.name == value)) {
      json['rarity'] = value;
    } else if (field == 'printedRarity') {
      if (value is String && Rarity.values.any((r) => r.name == value)) {
        json['printedRarity'] = value;
      } else {
        json.remove('printedRarity');
      }
    } else if (field == 'colors') {
      json['colors'] = '${value ?? ''}';
    }
  }
  json['names'] = names;
  final custom = CardData.fromJson(json).withCustomFields(customs.keys.toSet());
  return card.foil ? custom.asFoil() : custom;
}

/// The detail fields a user may edit on [info], with their values: every
/// scalar or list of words, nested records (an MtG card's faces) left out.
Map<String, Object?> editableInfoFields(CardInfo info) => {
      for (final MapEntry(key: key, value: value) in info.toJson().entries)
        if (key != 'game' && key != 'kind' && (value is! List || value.every((e) => e is String))) key: value,
    };

/// [info] with [customs] applied (the `card.…` ones aside); `null` without
/// details, and [info] itself when the result cannot be read back.
CardInfo? customizeInfo(CardInfo? info, CardCustoms customs) {
  if (info == null || customs.isEmpty) return info;
  final json = info.toJson();
  var changed = false;
  for (final MapEntry(key: key, value: value) in customs.entries) {
    if (key.startsWith(cardFieldPrefix)) continue;
    changed = true;
    if (value == null) {
      json.remove(key);
    } else {
      json[key] = value;
    }
  }
  if (!changed) return info;
  try {
    return CardInfo.fromJson(json);
  } on Object {
    return info;
  }
}

/// A field value as the user edits it: words of a list joined by commas.
String fieldText(Object? value) => switch (value) {
      null => '',
      final List list => list.join(', '),
      _ => '$value',
    };

/// A field value typed back, shaped like [base]: a number for a number,
/// words for a list, `null` for nothing.
Object? parseFieldText(String text, Object? base) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return switch (base) {
    int() => int.tryParse(trimmed) ?? trimmed,
    double() => double.tryParse(trimmed) ?? trimmed,
    bool() => trimmed.toLowerCase() == 'true',
    List() => [for (final w in trimmed.split(',')) if (w.trim().isNotEmpty) w.trim()],
    _ => trimmed,
  };
}

/// The frame a Yu-Gi-Oh! monster's [categories] imply (`Fusion`,
/// `Pendulum` → `fusion_pendulum`), the extra-deck kinds first; `null`
/// when they tell nothing (a spell, a trap, no category).
String? ygoFrameFromCategories(List<String> categories) {
  final words = categories.map((c) => c.toLowerCase()).toSet();
  const frames = ['link', 'xyz', 'synchro', 'fusion', 'ritual', 'effect', 'normal'];
  final frame = frames.where(words.contains).firstOrNull;
  if (frame == null) return null;
  return words.contains('pendulum') && frame != 'link' ? '${frame}_pendulum' : frame;
}
