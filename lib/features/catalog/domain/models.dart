enum Game {
  mtg(sealedPackCount: 6, draftRounds: 3),
  ygo(sealedPackCount: 5, draftRounds: 3),

  /// One Piece Card Game.
  opc(sealedPackCount: 6, draftRounds: 3);

  const Game({required this.sealedPackCount, required this.draftRounds});

  final int sealedPackCount;
  final int draftRounds;
}

/// Ordered from lowest to highest so `index` can be used to sort by value.
enum Rarity {
  common,
  uncommon,
  rare,
  superRare,

  /// A One Piece leader card.
  leader,
  ultraRare,
  mythic,
  special,

  /// Booster rarities of One Piece alternate prints, which keep their
  /// printed rarity (see [CardData.printedRarity]): the parallel art of a
  /// card, then the secret rares, then the manga art and the treasure
  /// rare, rarer still.
  parallel,
  secretRare,
  manga,
  treasure,
}

/// Booster products, in the order used to pick a set's default booster.
enum BoosterType { play, draft, standard, set, collector }

class CardData {
  const CardData({
    required this.id,
    required this.names,
    required this.rarity,
    this.colors = '',
    this.foil = false,
    this.score,
    this.passcode,
    this.scryfallId,
    this.artwork,
    this.printedRarity,
  });

  factory CardData.fromJson(Map<String, dynamic> json) => CardData(
        id: json['id'] as String,
        names: _localized(json['names']),
        rarity: Rarity.values.byName(json['rarity'] as String),
        printedRarity: switch (json['printedRarity']) { final String name => Rarity.values.byName(name), _ => null },
        colors: json['colors'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble(),
        passcode: json['passcode'] as String?,
        scryfallId: json['scryfallId'] as String?,
        artwork: json['artwork'] as String?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'names': names,
        'rarity': rarity.name,
        'printedRarity': ?printedRarity?.name,
        if (colors.isNotEmpty) 'colors': colors,
        'score': ?score,
        'passcode': ?passcode,
        'scryfallId': ?scryfallId,
        'artwork': ?artwork,
      };

  /// Printed code, e.g. `DMU-123` or `CIBR-FR077`.
  final String id;

  /// Card name per language code (`en`, `fr`).
  final Map<String, String> names;

  /// The rarity the booster deals the card at: for an alternate print
  /// (a parallel or manga art) its own, rarer one.
  final Rarity rarity;

  /// The rarity printed on the card when it differs from [rarity]: a
  /// manga art of a super rare is still a super rare.
  final Rarity? printedRarity;

  /// The rarity printed on the card.
  Rarity get printed => printedRarity ?? rarity;

  /// MtG color letters (`WUBRG`), used to balance commons.
  final String colors;
  final bool foil;

  /// Pick strength for draft bots (CubeCobra ELO); bots fall back to rarity.
  final double? score;

  /// Yu-Gi-Oh! passcode, the key of the card's text versions and picture.
  final String? passcode;

  /// Scryfall id of this MtG print, the key of its picture.
  final String? scryfallId;

  /// Another print's picture chosen for this card: a Scryfall id (MtG) or
  /// a YGOPRODeck image id (Yu-Gi-Oh!). See [withArtwork].
  final String? artwork;

  String nameFor(String languageCode) =>
      names[languageCode] ?? names['en'] ?? id;

  CardData asFoil() => CardData(
        id: id,
        names: names,
        rarity: rarity,
        colors: colors,
        foil: true,
        score: score,
        passcode: passcode,
        scryfallId: scryfallId,
        artwork: artwork,
        printedRarity: printedRarity,
      );

  /// This card shown with [artwork]'s picture (`null` for its own print's).
  CardData withArtwork(String? artwork) => CardData(
        id: id,
        names: names,
        rarity: rarity,
        colors: colors,
        foil: foil,
        score: score,
        passcode: passcode,
        scryfallId: scryfallId,
        artwork: artwork,
        printedRarity: printedRarity,
      );
}

/// A weighted pool that one or more booster slots draw from.
class BoosterSheet {
  BoosterSheet({
    required this.cards,
    required this.weights,
    this.foil = false,
    this.balanceColors = false,
    this.allowDuplicates = false,
  }) : totalWeight = weights.fold(0, (a, b) => a + b);

  factory BoosterSheet.fromJson(Map<String, dynamic> json, List<CardData> cards) {
    final entries = (json['cards'] as List).cast<List>();
    return BoosterSheet(
      cards: [for (final e in entries) cards[e[0] as int]],
      weights: [for (final e in entries) e[1] as int],
      foil: json['foil'] as bool? ?? false,
      balanceColors: json['balanceColors'] as bool? ?? false,
      allowDuplicates: json['allowDuplicates'] as bool? ?? false,
    );
  }

  final List<CardData> cards;
  final List<int> weights;
  final int totalWeight;
  final bool foil;
  final bool balanceColors;
  final bool allowDuplicates;
}

/// One possible pack layout: how many cards come from each sheet.
class BoosterVariant {
  const BoosterVariant({required this.weight, required this.contents});

  factory BoosterVariant.fromJson(Map<String, dynamic> json) => BoosterVariant(
        weight: json['weight'] as int,
        contents: (json['contents'] as Map<String, dynamic>).cast<String, int>(),
      );

  final int weight;
  final Map<String, int> contents;

  int get size => contents.values.fold(0, (a, b) => a + b);
}

class BoosterFormula {
  BoosterFormula({required this.variants, required this.sheets, this.topSlot})
      : totalWeight = variants.fold(0, (sum, v) => sum + v.weight);

  factory BoosterFormula.fromJson(Map<String, dynamic> json, List<CardData> cards) =>
      BoosterFormula(
        variants: [
          for (final v in json['variants'] as List)
            BoosterVariant.fromJson(v as Map<String, dynamic>),
        ],
        sheets: {
          for (final MapEntry(:key, :value)
              in (json['sheets'] as Map<String, dynamic>).entries)
            key: BoosterSheet.fromJson(value as Map<String, dynamic>, cards),
        },
        topSlot: json['topSlot'] as String?,
      );

  final List<BoosterVariant> variants;
  final Map<String, BoosterSheet> sheets;
  final int totalWeight;

  /// The name of the slot the variants differ by, the one card drawn from
  /// one sheet or another (a One Piece pack's hit), when the set names it.
  final String? topSlot;
}

/// Lightweight description of a set, read from the bundled index.
class SetSummary {
  const SetSummary({
    required this.code,
    required this.game,
    required this.names,
    required this.boosterTypes,
    required this.cardCount,
    required this.assetPath,
    this.releaseDate,
    this.prefix,
    this.icon,
  });

  factory SetSummary.fromJson(Map<String, dynamic> json) => SetSummary(
        code: json['code'] as String,
        prefix: json['prefix'] as String?,
        assetPath: json['path'] as String,
        game: Game.values.byName(json['game'] as String),
        names: _localized(json['names']),
        boosterTypes: [
          for (final type in json['boosterTypes'] as List)
            BoosterType.values.byName(type as String),
        ]..sort((a, b) => a.index.compareTo(b.index)),
        cardCount: json['cardCount'] as int,
        releaseDate: DateTime.tryParse(json['releaseDate'] as String? ?? ''),
        icon: json['icon'] as String?,
      );

  final String code;
  final Game game;
  final Map<String, String> names;
  final List<BoosterType> boosterTypes;
  final int cardCount;
  final DateTime? releaseDate;

  /// Bundled JSON file holding the full set.
  final String assetPath;

  /// Printed set code when [code] had to be made unique (`IOC2` -> `IOC`).
  final String? prefix;

  /// Bundled SVG of the set's expansion symbol, when it has one.
  final String? icon;

  String get displayCode => prefix ?? code;

  String nameFor(String languageCode) =>
      names[languageCode] ?? names['en'] ?? code;

  BoosterType get defaultBooster => boosterTypes.first;
}

class CardSet {
  const CardSet({
    required this.code,
    required this.game,
    required this.names,
    required this.cards,
    required this.boosters,
    this.attribution,
    this.prefix,
  });

  /// Reads a set written by the importers in `tool/`.
  factory CardSet.fromJson(Map<String, dynamic> json) {
    final cards = [
      for (final card in json['cards'] as List)
        CardData.fromJson(card as Map<String, dynamic>),
    ];
    return CardSet(
      code: json['code'] as String,
      game: Game.values.byName(json['game'] as String),
      names: _localized(json['names']),
      cards: cards,
      boosters: {
        for (final MapEntry(:key, :value)
            in (json['boosters'] as Map<String, dynamic>).entries)
          BoosterType.values.byName(key):
              BoosterFormula.fromJson(value as Map<String, dynamic>, cards),
      },
      attribution: json['license'] as String?,
      prefix: json['prefix'] as String?,
    );
  }

  final String code;
  final Game game;
  final Map<String, String> names;
  final List<CardData> cards;
  final Map<BoosterType, BoosterFormula> boosters;

  /// Credit line required by the data source's license.
  final String? attribution;

  /// Printed set code when [code] had to be made unique.
  final String? prefix;

  String get displayCode => prefix ?? code;

  String nameFor(String languageCode) =>
      names[languageCode] ?? names['en'] ?? code;

  /// The requested booster, or the set's preferred one for limited play.
  BoosterFormula booster([BoosterType? type]) => boosters[boosterType(type)]!;

  /// The type [booster] resolves [type] to: itself when the set has it, else
  /// the first type the set offers (in [BoosterType] order).
  BoosterType boosterType([BoosterType? type]) {
    if (type != null && (boosters[type] != null || boosters.isEmpty)) return type;
    if (boosters.isEmpty) return BoosterType.standard;
    return boosters.keys.reduce((a, b) => a.index <= b.index ? a : b);
  }
}

/// Keeps the non-empty entries of a `{"en": ..., "fr": ...}` map.
Map<String, String> _localized(Object? json) => {
      for (final MapEntry(:key, :value) in (json as Map<String, dynamic>).entries)
        if (value is String && value.isNotEmpty) key: value,
    };
