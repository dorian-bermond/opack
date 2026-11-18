import '../../catalog/domain/models.dart';
import '../../cube/domain/cube.dart';
import 'pool_config.dart';

/// Where a pool's cards come from.
sealed class PoolSource {
  const PoolSource();

  factory PoolSource.fromJson(Map<String, dynamic> json) => switch (json['type']) {
        'set' => SetSource(json['code'] as String),
        'cube' => CubeSource(json['id'] as String),
        'cards' => CardsSource([
            for (final card in json['cards'] as List) CardData.fromJson(card as Map<String, dynamic>),
          ]),
        final type => throw FormatException('Unknown pool source $type'),
      };

  Map<String, Object?> toJson();

  @override
  bool operator ==(Object other) =>
      other is PoolSource && other.runtimeType == runtimeType && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

/// Every card of a bundled set, once each.
class SetSource extends PoolSource {
  const SetSource(this.code);

  final String code;

  @override
  Map<String, Object?> toJson() => {'type': 'set', 'code': code};

  @override
  String toString() => 'set:$code';
}

/// Every card of an imported cube, as many times as it is listed.
class CubeSource extends PoolSource {
  const CubeSource(this.id);

  final String id;

  @override
  Map<String, Object?> toJson() => {'type': 'cube', 'id': id};

  @override
  String toString() => 'cube:$id';
}

/// Cards picked one by one from an online search, once each.
class CardsSource extends PoolSource {
  const CardsSource(this.cards);

  final List<CardData> cards;

  @override
  Map<String, Object?> toJson() => {'type': 'cards', 'cards': [for (final c in cards) c.toJson()]};

  /// Adds [more], skipping prints already picked.
  CardsSource plus(Iterable<CardData> more) {
    final ids = {for (final c in cards) c.id};
    return CardsSource([...cards, for (final c in more) if (ids.add(c.id)) c]);
  }

  @override
  String toString() => 'cards:${cards.map((c) => c.id).join(',')}';
}

/// Where a pool's tags and slots were prefilled from: a set's booster or
/// random packs. Only a memory, for the pack picture and re-prefilling.
sealed class PackLayout {
  const PackLayout();

  factory PackLayout.fromJson(Map<String, dynamic> json) => switch (json['type']) {
        'booster' => BoosterLayout(
            json['set'] as String,
            booster: BoosterType.values.where((t) => t.name == json['booster']).firstOrNull,
          ),
        'random' => RandomLayout(json['packSize'] as int),
        final type => throw FormatException('Unknown pack layout $type'),
      };

  Map<String, Object?> toJson();
}

/// A set's booster (commons, rare, foil...).
class BoosterLayout extends PackLayout {
  const BoosterLayout(this.setCode, {this.booster});

  final String setCode;
  final BoosterType? booster;

  @override
  Map<String, Object?> toJson() => {'type': 'booster', 'set': setCode, 'booster': ?booster?.name};

  @override
  bool operator ==(Object other) =>
      other is BoosterLayout && other.setCode == setCode && other.booster == booster;

  @override
  int get hashCode => Object.hash(setCode, booster);
}

/// [packSize] cards drawn from the whole pool, as with a cube.
class RandomLayout extends PackLayout {
  const RandomLayout([this.packSize = Cube.packSize]);

  final int packSize;

  @override
  Map<String, Object?> toJson() => {'type': 'random', 'packSize': packSize};

  @override
  bool operator ==(Object other) => other is RandomLayout && other.packSize == packSize;

  @override
  int get hashCode => packSize.hashCode;
}

/// Tag of the cards of one rarity, e.g. `rarity:rare`.
String rarityTag(Rarity rarity) => 'rarity:${rarity.name}';

/// The tag every card of a random pack pool carries.
const allCardsTag = 'all';

/// A tag: the cards carrying it and, when it was prefilled from a booster
/// sheet, each card's weight in draws and the sheet's flags.
class TagDef {
  const TagDef(
    this.cards, {
    this.weights = const {},
    this.foil = false,
    this.balanceColors = false,
    this.allowDuplicates = false,
    this.color,
    this.copiesSet = false,
    this.copies,
  });

  /// Reads either an id list (older pools) or a full definition.
  factory TagDef.fromJson(Object? json) => switch (json) {
        final List ids => TagDef(ids.cast<String>()),
        final Map<String, dynamic> map => TagDef(
            (map['cards'] as List).cast<String>(),
            weights: (map['weights'] as Map<String, dynamic>? ?? const {}).cast<String, int>(),
            foil: map['foil'] as bool? ?? false,
            balanceColors: map['balanceColors'] as bool? ?? false,
            allowDuplicates: map['allowDuplicates'] as bool? ?? false,
            color: map['color'] as int?,
            copiesSet: map.containsKey('copies'),
            copies: switch (map['copies']) { final int n when n >= 0 => n, _ => null },
          ),
        _ => throw FormatException('Unknown tag $json'),
      };

  final List<String> cards;

  /// Draw weight per card id for prefilled cards; others weigh like the
  /// average, or by how often they are listed.
  final Map<String, int> weights;
  final bool foil;
  final bool balanceColors;
  final bool allowDuplicates;

  /// The tag's color (ARGB), shown behind its tier and basket.
  final int? color;

  /// Whether the tag sets how many copies its cards have ([copies], `null`
  /// being unlimited), over the pool's preset; a value of a quality does.
  final bool copiesSet;
  final int? copies;

  Map<String, Object?> toJson() => {
        'cards': cards,
        if (weights.isNotEmpty) 'weights': weights,
        if (foil) 'foil': true,
        if (balanceColors) 'balanceColors': true,
        if (allowDuplicates) 'allowDuplicates': true,
        'color': ?color,
        if (copiesSet) 'copies': copies ?? -1,
      };

  TagDef withColor(int? color) => TagDef(
        cards,
        weights: weights,
        foil: foil,
        balanceColors: balanceColors,
        allowDuplicates: allowDuplicates,
        color: color,
        copiesSet: copiesSet,
        copies: copies,
      );

  /// This tag setting its cards' copies to [copies] (`null` unlimited)
  /// when [set], else leaving them to the pool.
  TagDef withCopies({required bool set, int? copies}) => TagDef(
        cards,
        weights: weights,
        foil: foil,
        balanceColors: balanceColors,
        allowDuplicates: allowDuplicates,
        color: color,
        copiesSet: set,
        copies: set ? copies : null,
      );

  /// This tag on exactly [ids], keeping known weights and flags.
  TagDef withCards(Iterable<String> ids) {
    final kept = ids.toSet().toList();
    return TagDef(
      kept,
      weights: {for (final id in kept) id: ?weights[id]},
      foil: foil,
      balanceColors: balanceColors,
      allowDuplicates: allowDuplicates,
      color: color,
      copiesSet: copiesSet,
      copies: copies,
    );
  }

  /// This tag with [ids] added, their weights from [weightOf] when given.
  TagDef plus(Iterable<String> ids, {int? Function(String id)? weightOf}) {
    final present = cards.toSet();
    final added = [for (final id in ids) if (present.add(id)) id];
    return TagDef(
      [...cards, ...added],
      weights: {...weights, for (final id in added) id: ?weightOf?.call(id)},
      foil: foil,
      balanceColors: balanceColors,
      allowDuplicates: allowDuplicates,
      color: color,
      copiesSet: copiesSet,
      copies: copies,
    );
  }
}

/// One tag a slot may pull from, with its chance relative to the slot's
/// other options.
class SlotOption {
  const SlotOption(this.tag, [this.weight = 1]);

  factory SlotOption.fromJson(Map<String, dynamic> json) =>
      SlotOption(json['tag'] as String, json['weight'] as int? ?? 1);

  final String tag;
  final int weight;

  Map<String, Object?> toJson() => {'tag': tag, 'weight': weight};

  @override
  bool operator ==(Object other) => other is SlotOption && other.tag == tag && other.weight == weight;

  @override
  int get hashCode => Object.hash(tag, weight);
}

/// A booster slot: [count] cards, each pulled from one of the [options] by
/// chance (a weight 1 option against a weight 3 one is drawn one time in
/// four).
class PackSlot {
  const PackSlot(this.count, this.options, {this.name});

  /// A slot with a single option.
  PackSlot.single(String tag, int count) : this(count, [SlotOption(tag)]);

  factory PackSlot.fromJson(Map<String, dynamic> json) => PackSlot(
        json['count'] as int,
        switch (json['tag']) {
          final String tag => [SlotOption(tag)],
          _ => [
              for (final option in json['options'] as List)
                SlotOption.fromJson(option as Map<String, dynamic>),
            ],
        },
        name: switch (json['name']) { final String n when n.trim().isNotEmpty => n.trim(), _ => null },
      );

  final int count;
  final List<SlotOption> options;

  /// A name of the user's, shown in place of the options ("Hit slot").
  final String? name;

  int get totalWeight => options.fold(0, (sum, o) => sum + o.weight);

  PackSlot copyWith({int? count, List<SlotOption>? options, String? Function()? name}) =>
      PackSlot(count ?? this.count, options ?? this.options, name: name == null ? this.name : name());

  Map<String, Object?> toJson() => {
        'count': count,
        'options': [for (final option in options) option.toJson()],
        'name': ?name,
      };

  @override
  bool operator ==(Object other) =>
      other is PackSlot &&
      other.count == count &&
      other.name == name &&
      other.options.length == options.length &&
      [for (var i = 0; i < options.length; i++) other.options[i] == options[i]].every((same) => same);

  @override
  int get hashCode => Object.hash(count, name, Object.hashAll(options));
}

/// A kind of booster a pool can open: a name and its slots.
class BoosterDef {
  const BoosterDef(this.name, this.slots);

  factory BoosterDef.fromJson(Map<String, dynamic> json) => BoosterDef(
        json['name'] as String,
        [for (final slot in json['slots'] as List) PackSlot.fromJson(slot as Map<String, dynamic>)],
      );

  final String name;
  final List<PackSlot> slots;

  Map<String, Object?> toJson() => {'name': name, 'slots': [for (final slot in slots) slot.toJson()]};

  BoosterDef copyWith({String? name, List<PackSlot>? slots}) =>
      BoosterDef(name ?? this.name, slots ?? this.slots);

  /// The name of the booster a prefill creates.
  static const defaultName = 'Booster';
}

/// How a format is played: packs opened all at once, or drafted.
enum FormatKind { sealed, draft }

/// One pack of a format: which booster, and for a draft how many cards
/// each player picks per pass and how many they then burn.
class FormatRound {
  const FormatRound(this.booster, {this.picks = 1, this.burn = 0});

  factory FormatRound.fromJson(Map<String, dynamic> json) => FormatRound(
        json['booster'] as String,
        picks: json['picks'] as int? ?? 1,
        burn: json['burn'] as int? ?? 0,
      );

  final String booster;
  final int picks;
  final int burn;

  Map<String, Object?> toJson() => {'booster': booster, 'picks': picks, 'burn': burn};

  FormatRound copyWith({String? booster, int? picks, int? burn}) =>
      FormatRound(booster ?? this.booster, picks: picks ?? this.picks, burn: burn ?? this.burn);
}

/// A way to play a pool: which boosters in which order, opened at once
/// (sealed) or drafted round by round with [seats] players.
class PlayFormat {
  const PlayFormat({
    required this.id,
    required this.name,
    required this.kind,
    required this.rounds,
    this.seats = 8,
  });

  factory PlayFormat.fromJson(Map<String, dynamic> json) => PlayFormat(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: FormatKind.values.byName(json['kind'] as String),
        rounds: [
          for (final round in json['rounds'] as List) FormatRound.fromJson(round as Map<String, dynamic>),
        ],
        seats: json['seats'] as int? ?? 8,
      );

  final String id;
  final String name;
  final FormatKind kind;
  final List<FormatRound> rounds;
  final int seats;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'rounds': [for (final round in rounds) round.toJson()],
        'seats': seats,
      };

  PlayFormat copyWith({String? name, FormatKind? kind, List<FormatRound>? rounds, int? seats}) => PlayFormat(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        rounds: rounds ?? this.rounds,
        seats: seats ?? this.seats,
      );

  /// How many packs of each booster the format opens, per player for a draft.
  Map<String, int> get packsPerPlayer {
    final counts = <String, int>{};
    for (final round in rounds) {
      counts.update(round.booster, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// The formats a pool starts with: the game's sealed and draft, on the
  /// first booster.
  static List<PlayFormat> defaults(Game game, String booster) => [
        PlayFormat(
          id: 'sealed',
          name: 'Sealed',
          kind: FormatKind.sealed,
          rounds: [for (var i = 0; i < game.sealedPackCount; i++) FormatRound(booster)],
        ),
        PlayFormat(
          id: 'draft',
          name: 'Draft',
          kind: FormatKind.draft,
          rounds: [for (var i = 0; i < game.draftRounds; i++) FormatRound(booster)],
        ),
      ];
}

/// Tags and slots as a set's booster, a cube or a card list suggest them.
typedef Prefill = ({Map<String, TagDef> tags, List<PackSlot> slots});

/// A set's booster as pool data: one tag per sheet of the main variant with
/// the sheet's weights and flags, one slot per sheet, plus rarity tags.
/// A sheet named as a quality value (`version:base`) is a tag even when no
/// slot draws from it, so the quality comes whole.
Prefill prefillFromSet(CardSet set, {BoosterType? booster}) {
  final formula = set.booster(booster);
  final tags = <String, TagDef>{};
  TagDef tagOf(BoosterSheet sheet) => TagDef(
        [for (var i = 0; i < sheet.cards.length; i++) if (sheet.weights[i] > 0) sheet.cards[i].id],
        weights: {for (var i = 0; i < sheet.cards.length; i++) if (sheet.weights[i] > 0) sheet.cards[i].id: sheet.weights[i]},
        foil: sheet.foil,
        balanceColors: sheet.balanceColors,
        allowDuplicates: sheet.allowDuplicates,
      );
  final slots = <PackSlot>[];
  for (final (name, count) in formulaSlots(formula)) {
    for (final option in name) {
      if (formula.sheets[option.tag] case final sheet?) tags[option.tag] = tagOf(sheet);
    }
    slots.add(PackSlot(count, name));
  }
  for (final MapEntry(key: name, value: sheet) in formula.sheets.entries) {
    if (Pool.qualityOf(name) != null && !name.startsWith('rarity:')) tags.putIfAbsent(name, () => tagOf(sheet));
  }
  // Plain tags in slot order, then quality tags in the formula's sheet order,
  // so a quality's values come in order.
  final plain = {for (final MapEntry(key: name, value: def) in tags.entries) if (Pool.qualityOf(name) == null) name: def};
  final qualities = {for (final name in formula.sheets.keys) if (Pool.qualityOf(name) != null) name: ?tags[name]};
  return (tags: {...plain, ...qualities, ...rarityTags(set.cards)}, slots: slots);
}

/// A formula's pack as slots: what every variant shares, one slot per
/// sheet; then, when the variants differ by one card drawn from one sheet
/// each (a "top slot" of super rare, leader, secret rare…), one slot whose
/// options are those sheets, weighted as the variants; otherwise, the
/// commonest variant's remaining sheets as plain slots.
List<(List<SlotOption>, int)> formulaSlots(BoosterFormula formula) {
  final variants = formula.variants.where((v) => v.contents.isNotEmpty).toList();
  if (variants.isEmpty) return const [];
  final shared = <String, int>{};
  for (final MapEntry(key: name, value: count) in variants.first.contents.entries) {
    final least = variants.fold(count, (m, v) => (v.contents[name] ?? 0) < m ? (v.contents[name] ?? 0) : m);
    if (least > 0) shared[name] = least;
  }
  final slots = <(List<SlotOption>, int)>[
    for (final MapEntry(key: name, value: count) in shared.entries)
      if (formula.sheets.containsKey(name)) ([SlotOption(name)], count),
  ];
  // What each variant adds beyond the shared part.
  final extras = [
    for (final v in variants)
      {
        for (final MapEntry(key: name, value: count) in v.contents.entries)
          if (count - (shared[name] ?? 0) > 0) name: count - (shared[name] ?? 0),
      },
  ];
  if (extras.every((e) => e.isEmpty)) return slots;
  final oneEach = extras.every((e) => e.length == 1 && e.values.single == 1);
  if (oneEach && variants.length > 1) {
    final options = <String, int>{};
    for (final (i, e) in extras.indexed) {
      options.update(e.keys.single, (w) => w + variants[i].weight, ifAbsent: () => variants[i].weight);
    }
    slots.add(([
      for (final MapEntry(key: name, value: weight) in options.entries)
        if (formula.sheets.containsKey(name)) SlotOption(name, weight),
    ], 1));
    return slots;
  }
  final main = variants.reduce((a, b) => b.weight > a.weight ? b : a);
  for (final MapEntry(key: name, value: count) in extras[variants.indexOf(main)].entries) {
    if (formula.sheets.containsKey(name)) slots.add(([SlotOption(name)], count));
  }
  return slots;
}

/// Random packs as pool data: every card in [allCardsTag], one slot of
/// [packSize] from it, plus rarity tags.
Prefill prefillRandom(Iterable<CardData> cards, {int packSize = Cube.packSize}) => (
      tags: {
        allCardsTag: TagDef([for (final card in cards) card.id]),
        ...rarityTags(cards),
      },
      slots: [PackSlot.single(allCardsTag, packSize)],
    );

/// [prefill] with every card of [cards] not yet in a sheet tag added to the
/// sheet tags holding cards of its rarity, at the sheet's average weight:
/// how a set's booster takes cards from other sources.
Prefill withCardsByRarity(Prefill prefill, Iterable<CardData> cards) {
  final byId = {for (final card in cards) card.id: card};
  final tags = {...prefill.tags};
  for (final MapEntry(key: name, value: def) in prefill.tags.entries) {
    if (def.weights.isEmpty) continue;
    final rarities = {for (final id in def.cards) if (byId[id] case final card?) card.rarity};
    final average = (def.weights.values.fold(0, (a, b) => a + b) / def.weights.length).round().clamp(1, 1 << 30);
    final members = def.cards.toSet();
    tags[name] = def.plus(
      [for (final card in cards) if (!members.contains(card.id) && rarities.contains(card.rarity)) card.id],
      weightOf: (_) => average,
    );
  }
  return (tags: tags, slots: prefill.slots);
}

/// One tag per rarity present in [cards].
Map<String, TagDef> rarityTags(Iterable<CardData> cards) {
  final byRarity = <Rarity, List<String>>{};
  for (final card in cards) {
    (byRarity[card.rarity] ??= []).add(card.id);
  }
  return {
    for (final rarity in Rarity.values)
      if (byRarity[rarity] case final ids?) rarityTag(rarity): TagDef(ids),
  };
}

/// A named card pool that packs are dealt from: its sources, the tags its
/// cards carry, the slots of its packs and how many copies of each card it
/// holds. A set or a cube only prefills tags and slots; the user owns them
/// all alike afterwards.
class Pool {
  const Pool({
    required this.id,
    required this.game,
    required this.name,
    required this.sources,
    required this.layout,
    required this.config,
    required this.updatedAt,
    this.tags = const {},
    this.boosters = const [],
    this.formats = const [],
    this.artworks = const {},
    this.descending = const {},
    this.tierlistQuality,
    this.cover,
  });

  factory Pool.fromJson(Map<String, dynamic> json) => Pool(
        id: json['id'] as String,
        game: Game.values.byName(json['game'] as String),
        name: json['name'] as String,
        sources: [
          for (final source in json['sources'] as List)
            PoolSource.fromJson(source as Map<String, dynamic>),
        ],
        layout: PackLayout.fromJson(json['layout'] as Map<String, dynamic>),
        config: PoolConfig.fromJson(json['config'] as Map<String, dynamic>),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        tags: {
          for (final MapEntry(:key, :value) in (json['tags'] as Map<String, dynamic>? ?? const {}).entries)
            key: TagDef.fromJson(value),
        },
        boosters: json['boosters'] != null
            ? [
                for (final booster in json['boosters'] as List)
                  BoosterDef.fromJson(booster as Map<String, dynamic>),
              ]
            : json['slots'] != null
                // Pools saved with a single slot list.
                ? [
                    BoosterDef(BoosterDef.defaultName, [
                      for (final slot in json['slots'] as List) PackSlot.fromJson(slot as Map<String, dynamic>),
                    ]),
                  ]
                : const [],
        formats: [
          for (final format in json['formats'] as List? ?? const [])
            PlayFormat.fromJson(format as Map<String, dynamic>),
        ],
        artworks: (json['artworks'] as Map<String, dynamic>? ?? const {}).cast<String, String>(),
        descending: (json['descending'] as Map<String, dynamic>? ?? const {}).cast<String, bool>(),
        tierlistQuality: json['tierlistQuality'] as String?,
        cover: json['cover'] as String?,
      );

  /// A set's booster print run: every card unlimited, tags and slots
  /// prefilled from the set's booster.
  factory Pool.ofSet(CardSet set, {required String name, BoosterType? booster, String? id}) {
    final (:tags, :slots) = prefillFromSet(set, booster: booster);
    return Pool(
      id: id ?? newId(set.game),
      game: set.game,
      name: name,
      sources: [SetSource(set.code)],
      layout: BoosterLayout(set.code, booster: booster),
      config: const PoolConfig.open(),
      updatedAt: DateTime.now(),
      tags: tags,
      boosters: [BoosterDef(BoosterDef.defaultName, slots)],
    );
  }

  /// No cards yet: sets and cubes are added in the editor.
  factory Pool.empty(Game game, {required String name, String? id}) => Pool(
        id: id ?? newId(game),
        game: game,
        name: name,
        sources: const [],
        layout: const RandomLayout(),
        config: const PoolConfig.closed(),
        updatedAt: DateTime.now(),
      );

  /// A cube as listed, dealt in random packs.
  factory Pool.ofCube(Cube cube, {String? id}) {
    final (:tags, :slots) = prefillRandom(cube.cards);
    return Pool(
      id: id ?? newId(cube.game),
      game: cube.game,
      name: cube.name,
      sources: [CubeSource(cube.id)],
      layout: const RandomLayout(),
      config: const PoolConfig.closed(),
      updatedAt: DateTime.now(),
      tags: tags,
      boosters: [BoosterDef(BoosterDef.defaultName, slots)],
    );
  }

  static String newId(Game game) => '${game.name}-${DateTime.now().microsecondsSinceEpoch}';

  Map<String, Object?> toJson() => {
        'id': id,
        'game': game.name,
        'name': name,
        'sources': [for (final source in sources) source.toJson()],
        'layout': layout.toJson(),
        'config': config.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
        if (tags.isNotEmpty) 'tags': {for (final MapEntry(:key, :value) in tags.entries) key: value.toJson()},
        if (boosters.isNotEmpty) 'boosters': [for (final booster in boosters) booster.toJson()],
        if (formats.isNotEmpty) 'formats': [for (final format in formats) format.toJson()],
        if (artworks.isNotEmpty) 'artworks': artworks,
        if (descending.isNotEmpty) 'descending': descending,
        'tierlistQuality': ?tierlistQuality,
        'cover': ?cover,
      };

  final String id;
  final Game game;
  final String name;
  final List<PoolSource> sources;
  final PackLayout layout;
  final PoolConfig config;
  final DateTime updatedAt;

  /// Every tag, by name.
  final Map<String, TagDef> tags;

  /// The kinds of booster the pool opens, the first being the default.
  final List<BoosterDef> boosters;

  /// The ways to play the pool; empty means the game's defaults.
  final List<PlayFormat> formats;

  /// Another print's picture chosen for a card, by card id (see
  /// [CardData.artwork]); applied when the pool is resolved.
  final Map<String, String> artworks;

  /// Per quality, whether its values read best first; see [isDescending].
  final Map<String, bool> descending;

  /// The quality the tierlist was last on, to open on it again.
  final String? tierlistQuality;

  /// A picture of the user's own for the booster, as a file path on this
  /// device; `null` for the set's picture.
  final String? cover;

  /// With [cover] as the booster picture (`null`: the set's).
  Pool withCover(String? cover) => Pool(
        id: id,
        game: game,
        name: name,
        sources: sources,
        layout: layout,
        config: config,
        updatedAt: DateTime.now(),
        tags: tags,
        boosters: boosters,
        formats: formats,
        artworks: artworks,
        descending: descending,
        tierlistQuality: tierlistQuality,
        cover: cover,
      );

  /// The quality the tierlist opens on: the last one used, while it
  /// exists, else the first.
  String? get defaultTierlistQuality =>
      tierlistQuality != null && qualities.contains(tierlistQuality) ? tierlistQuality : qualities.firstOrNull;

  /// Shows [cardId] with [artwork]'s picture, or its own again with `null`.
  Pool withArtwork(String cardId, String? artwork) => copyWith(artworks: {
        for (final MapEntry(:key, :value) in artworks.entries)
          if (key != cardId) key: value,
        cardId: ?artwork,
      });

  /// [card] with the artwork chosen for it, if any.
  CardData withChosenArtwork(CardData card) => switch (artworks[card.id]) {
        final artwork? => card.withArtwork(artwork),
        null => card,
      };

  /// The slots of the default booster.
  List<PackSlot> get slots => boosters.firstOrNull?.slots ?? const [];

  /// The booster called [name], else the default one.
  BoosterDef? booster(String name) =>
      boosters.where((b) => b.name == name).firstOrNull ?? boosters.firstOrNull;

  /// The formats to play: the saved ones, else the game's defaults on the
  /// default booster.
  List<PlayFormat> get playFormats => formats.isNotEmpty
      ? formats
      : PlayFormat.defaults(game, boosters.firstOrNull?.name ?? BoosterDef.defaultName);

  /// Whether tags and slots were never filled (older pools, empty ones).
  bool get needsPrefill => tags.isEmpty && boosters.isEmpty;

  /// Adds or replaces the booster called like [booster].
  Pool withBooster(BoosterDef booster) => copyWith(boosters: [
        for (final b in boosters)
          if (b.name != booster.name) b,
        booster,
      ]);

  /// Drops the booster [name]; format rounds on it move to the default.
  Pool withoutBooster(String name) {
    final rest = [for (final b in boosters) if (b.name != name) b];
    final fallback = rest.firstOrNull?.name ?? BoosterDef.defaultName;
    return copyWith(
      boosters: rest,
      formats: [
        for (final format in formats)
          format.copyWith(rounds: [
            for (final round in format.rounds)
              round.booster == name ? round.copyWith(booster: fallback) : round,
          ]),
      ],
    );
  }

  /// Adds or replaces the format with [format]'s id.
  Pool withFormat(PlayFormat format) => copyWith(formats: [
        for (final f in playFormats)
          if (f.id != format.id) f,
        format,
      ]);

  Pool withoutFormat(String id) => copyWith(formats: [for (final f in playFormats) if (f.id != id) f]);

  /// The tags of one card.
  Iterable<String> tagsOf(String cardId) => [
        for (final MapEntry(key: tag, value: def) in tags.entries)
          if (def.cards.contains(cardId)) tag,
      ];

  /// The quality a tag belongs to: the part before `:` in `rarity:rare`,
  /// `null` for a plain tag. Tags of one quality are exclusive: a card
  /// holds at most one of them.
  static String? qualityOf(String tag) {
    final i = tag.indexOf(':');
    return i > 0 ? tag.substring(0, i) : null;
  }

  /// The tag `quality:value`.
  static String qualityTag(String quality, String value) => '$quality:$value';

  /// Every quality of the pool, in the order its tags list them.
  List<String> get qualities => {for (final tag in tags.keys) ?qualityOf(tag)}.toList();

  /// The values of [quality] as stored: its tags in the pool's order,
  /// lowest first (common before rare).
  List<String> valuesOf(String quality) => [for (final tag in tags.keys) if (qualityOf(tag) == quality) tag];

  /// Whether [quality] reads best first, i.e. its stored order reversed:
  /// as chosen, else yes for the rarity, no otherwise.
  bool isDescending(String quality) => descending[quality] ?? (quality == 'rarity');

  /// The values of [quality] in their preferred order: see [isDescending].
  List<String> orderedValuesOf(String quality) =>
      isDescending(quality) ? valuesOf(quality).reversed.toList() : valuesOf(quality);

  Pool withQualityDescending(String quality, bool value) =>
      copyWith(descending: {...descending, quality: value});

  /// Reorders the values of [quality] as [stored] lists them (stored
  /// order, lowest first); they keep the place of the first one among the
  /// other tags.
  Pool withValuesOrder(String quality, List<String> stored) {
    final values = valuesOf(quality);
    if (values.isEmpty || stored.toSet().length != values.length || !values.toSet().containsAll(stored)) return this;
    final ordered = <String, TagDef>{};
    for (final MapEntry(:key, :value) in tags.entries) {
      if (qualityOf(key) == quality) {
        if (key == values.first) {
          for (final tag in stored) {
            ordered[tag] = tags[tag]!;
          }
        }
        continue;
      }
      ordered[key] = value;
    }
    return copyWith(tags: ordered);
  }

  /// The plain tags: yes/no traits, outside any quality.
  List<String> get plainTags => [for (final tag in tags.keys) if (qualityOf(tag) == null) tag];

  /// Sets the copies [tag] gives its cards (see [TagDef.copiesSet]).
  Pool withTagCopies(String tag, {required bool set, int? copies}) =>
      copyWith(tags: {...tags, tag: (tags[tag] ?? const TagDef([])).withCopies(set: set, copies: copies)});

  /// The copies a quality value sets for card [id], listed [listed]
  /// times: `(set: false)` when no value of its sets any.
  ({bool set, int? copies}) valueCopiesOf(String id, {int listed = 1}) {
    for (final MapEntry(key: tag, value: def) in tags.entries) {
      if (def.copiesSet && qualityOf(tag) != null && def.cards.contains(id)) {
        return (set: true, copies: def.copies == null ? null : def.copies! * listed);
      }
    }
    return (set: false, copies: null);
  }

  /// Copies of card [id] in the pool: its own count when set, else its
  /// quality value's, else the pool's preset.
  int? copiesOf(String id, {int listed = 1}) {
    if (config.overrides.containsKey(id)) return config.overrides[id];
    final byValue = valueCopiesOf(id, listed: listed);
    return byValue.set ? byValue.copies : config.copiesOf(id, listed: listed);
  }

  /// Colors [tag] (`null` clears), creating it when new.
  Pool withTagColor(String tag, int? color) =>
      copyWith(tags: {...tags, tag: (tags[tag] ?? const TagDef([])).withColor(color)});

  /// The other tags of [tag]'s quality, none for a plain tag.
  Iterable<String> siblingsOf(String tag) {
    final quality = qualityOf(tag);
    if (quality == null) return const [];
    return tags.keys.where((t) => t != tag && qualityOf(t) == quality);
  }

  /// Puts [cardId] in [tag] right before [before] (last when `null` or
  /// not in the tag): the order of a tag's cards is their rank within it.
  Pool withCardInTag(String tag, String cardId, {String? before}) {
    final cards = [for (final id in tags[tag]?.cards ?? const <String>[]) if (id != cardId) id];
    final at = before == null ? -1 : cards.indexOf(before);
    cards.insert(at < 0 ? cards.length : at, cardId);
    return withTag(tag, cards);
  }

  /// Moves [tag] right before [before] (last when `null`) among the
  /// pool's tags: the order of a quality's tags ranks its values.
  Pool withTagBefore(String tag, String? before) {
    final def = tags[tag];
    if (def == null || tag == before) return this;
    final ordered = <String, TagDef>{};
    for (final MapEntry(:key, :value) in tags.entries) {
      if (key == tag) continue;
      if (key == before) ordered[tag] = def;
      ordered[key] = value;
    }
    if (!ordered.containsKey(tag)) ordered[tag] = def;
    return copyWith(tags: ordered);
  }

  /// Sets which cards carry [tag] (creating it when new), in that order;
  /// cards gaining a quality tag lose the other tags of that quality.
  Pool withTag(String tag, Iterable<String> cardIds) {
    final ids = cardIds.toSet();
    final gained = ids.difference({...?tags[tag]?.cards});
    return copyWith(tags: {
      ...tags,
      for (final sibling in siblingsOf(tag))
        if (gained.isNotEmpty && tags[sibling]!.cards.any(gained.contains))
          sibling: tags[sibling]!.withCards(tags[sibling]!.cards.where((id) => !gained.contains(id))),
      tag: (tags[tag] ?? const TagDef([])).withCards(ids),
    });
  }

  /// Drops [tag]; slots of every booster lose that option, and go when
  /// nothing is left.
  Pool withoutTag(String tag) => copyWith(
        tags: {...tags}..remove(tag),
        boosters: [
          for (final booster in boosters)
            booster.copyWith(slots: [
              for (final slot in booster.slots)
                if (slot.options.any((o) => o.tag != tag))
                  slot.copyWith(options: [for (final o in slot.options) if (o.tag != tag) o]),
            ]),
        ],
      );

  /// Renames [tag] to [name] in place, cards, weights, color and the
  /// slots pulling from it included; nothing when [name] is taken.
  Pool withTagRenamed(String tag, String name) {
    if (tag == name || !tags.containsKey(tag) || tags.containsKey(name)) return this;
    return copyWith(
      tags: {for (final MapEntry(:key, :value) in tags.entries) (key == tag ? name : key): value},
      boosters: [
        for (final booster in boosters)
          booster.copyWith(slots: [
            for (final slot in booster.slots)
              slot.copyWith(options: [
                for (final o in slot.options) o.tag == tag ? SlotOption(name, o.weight) : o,
              ]),
          ]),
      ],
      descending: {
        for (final MapEntry(:key, :value) in descending.entries)
          (key == qualityOf(tag) && qualityOf(name) != null ? qualityOf(name)! : key): value,
      },
    );
  }

  /// Replaces the tags and the default booster's slots with [prefill],
  /// remembering [layout]; other boosters stay.
  Pool prefilled(Prefill prefill, {PackLayout? layout}) => copyWith(
        tags: prefill.tags,
        boosters: [
          BoosterDef(boosters.firstOrNull?.name ?? BoosterDef.defaultName, prefill.slots),
          ...boosters.skip(1),
        ],
        layout: layout,
      );

  Iterable<String> get setCodes => {
        for (final source in sources)
          if (source case SetSource(:final code)) code,
        if (layout case BoosterLayout(:final setCode)) setCode,
      };

  Iterable<String> get cubeIds => [
        for (final source in sources)
          if (source case CubeSource(:final id)) id,
      ];

  Pool copyWith({
    String? id,
    String? name,
    List<PoolSource>? sources,
    PackLayout? layout,
    PoolConfig? config,
    Map<String, TagDef>? tags,
    List<BoosterDef>? boosters,
    List<PlayFormat>? formats,
    List<PackSlot>? slots,
    Map<String, String>? artworks,
    Map<String, bool>? descending,
    String? tierlistQuality,
  }) {
    var kinds = boosters ?? this.boosters;
    if (slots != null) {
      // The default booster's slots; created when the pool has none.
      kinds = kinds.isEmpty
          ? [BoosterDef(BoosterDef.defaultName, slots)]
          : [kinds.first.copyWith(slots: slots), ...kinds.skip(1)];
    }
    return Pool(
      id: id ?? this.id,
      game: game,
      name: name ?? this.name,
      sources: sources ?? this.sources,
      layout: layout ?? this.layout,
      config: config ?? this.config,
      updatedAt: DateTime.now(),
      tags: tags ?? this.tags,
      boosters: kinds,
      formats: formats ?? this.formats,
      artworks: artworks ?? this.artworks,
      descending: descending ?? this.descending,
      tierlistQuality: tierlistQuality ?? this.tierlistQuality,
      cover: cover,
    );
  }

  /// Adds [source] bringing [cards]: they join the rarity tags, the
  /// all-cards tag when the pool has one, the sheet tags holding their
  /// rarity (given [existing], the cards already in the pool) and, for a
  /// set with [set] given, the tags named like its own sheets with the
  /// sheet weights.
  Pool withSource(
    PoolSource source, {
    Iterable<CardData> cards = const [],
    Iterable<CardData> existing = const [],
    CardSet? set,
  }) {
    if (sources.contains(source)) return this;
    var tags = {...this.tags};
    for (final MapEntry(key: tag, value: def) in rarityTags(cards).entries) {
      tags[tag] = (tags[tag] ?? const TagDef([])).plus(def.cards);
    }
    if (tags[allCardsTag] case final all?) {
      tags[allCardsTag] = all.plus(cards.map((c) => c.id));
    }
    if (set != null) {
      final (tags: sheets, slots: _) = prefillFromSet(set);
      for (final MapEntry(key: name, value: def) in sheets.entries) {
        if (name.startsWith('rarity:')) continue;
        if (tags[name] case final current?) {
          tags[name] = current.plus(def.cards, weightOf: (id) => def.weights[id]);
        }
      }
    }
    tags = withCardsByRarity((tags: tags, slots: slots), [...existing, ...cards]).tags;
    return copyWith(sources: [...sources, source], tags: tags);
  }

  /// Removes [source]; a booster layout of that set falls back to another
  /// set of the pool, else random packs. Tags keep their cards: ones no
  /// longer in the pool are simply never dealt.
  Pool withoutSource(PoolSource source) {
    final rest = [...sources]..remove(source);
    var layout = this.layout;
    if (layout case BoosterLayout(:final setCode) when source == SetSource(setCode)) {
      final other = rest.whereType<SetSource>().firstOrNull;
      layout = other == null ? const RandomLayout() : BoosterLayout(other.code);
    }
    return copyWith(sources: rest, layout: layout);
  }
}
