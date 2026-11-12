import '../../catalog/domain/models.dart';
import '../../cube/domain/cube.dart';
import '../../packs/domain/pack_generator.dart';
import '../../packs/domain/pack_source.dart';
import '../../packs/domain/pool_dealer.dart';
import 'pool.dart';
import 'pool_config.dart';

/// One distinct card of a pool and how often its sources list it.
typedef PoolEntry = ({CardData card, int listed});

/// One kind of booster of a pool, ready to deal.
class BoosterPlay {
  const BoosterPlay({required this.packSize, required this.newSource, this.packCount});

  final int packSize;

  /// Packs it can deal; `null` without limit.
  final int? packCount;
  final PackSource Function() newSource;

  bool canDeal(int packs) => packCount == null || packCount! >= packs;
}

/// A [Pool] resolved against its loaded sets and cubes, ready to deal.
class PlayPool {
  const PlayPool({
    required this.pool,
    required this.entries,
    required this.boosters,
    required this.tagCards,
    this.sets = const {},
    this.layoutSet,
    this.cardCount,
    this.unplaced = 0,
  });

  /// Merges the sources of [pool] (cards listed by several sources add up)
  /// and builds each booster from the pool's tags and slots. Missing
  /// sources are skipped. A pool never filled (older ones) takes its
  /// layout's prefill.
  factory PlayPool.resolve(
    Pool saved, {
    required Map<String, CardSet> sets,
    required Map<String, Cube> cubes,
  }) {
    final byId = <String, PoolEntry>{};
    void add(CardData card) => byId.update(card.id, (e) => (card: e.card, listed: e.listed + 1),
        ifAbsent: () => (card: card, listed: 1));
    for (final source in saved.sources) {
      switch (source) {
        case SetSource(:final code):
          sets[code]?.cards.forEach(add);
        case CubeSource(:final id):
          cubes[id]?.cards.forEach(add);
        case CardsSource(:final cards):
          cards.forEach(add);
      }
    }
    final entries = byId.values.toList();
    final pool = migrated(saved, sets: sets, cards: entries.map((e) => e.card));
    int? copiesOf(CardData card) =>
        pool.config.copiesOf(card.id, listed: byId[card.id]?.listed ?? 1);

    final layoutSet = switch (pool.layout) {
      BoosterLayout(:final setCode) => sets[setCode],
      RandomLayout() => null,
    };
    final booster = switch (pool.layout) {
      BoosterLayout(:final booster) => booster,
      RandomLayout() => null,
    };
    final tagCards = {
      for (final MapEntry(key: tag, value: def) in pool.tags.entries)
        tag: [for (final id in def.cards) if (byId[id] case final entry?) entry.card],
    };
    final prefill = layoutSet == null ? null : prefillFromSet(layoutSet, booster: booster);
    final exactTags = prefill != null && sameTags(pool, prefill);
    final exactPool = layoutSet != null &&
        pool.config.preset == PoolPreset.open &&
        pool.sources.length == 1 &&
        pool.sources.single == SetSource(layoutSet.code);

    final boosters = <String, BoosterPlay>{};
    for (final kind in pool.boosters) {
      if (entries.isEmpty) {
        boosters[kind.name] = BoosterPlay(
          packSize: kind.slots.fold(0, (sum, slot) => sum + slot.count),
          packCount: 0,
          newSource: () => throw StateError('Empty pool'),
        );
        continue;
      }
      // A set alone under its own open boosters, left as prefilled, keeps
      // the full formula: pack variants, color balance.
      if (exactPool && exactTags && sameSlots(kind.slots, prefill.slots)) {
        final formula = layoutSet.booster(booster);
        boosters[kind.name] = BoosterPlay(
          packSize: PoolDealer.mainVariant(formula).size,
          newSource: () => PackGenerator(formula),
        );
        continue;
      }
      final formula = poolFormula(pool, kind.slots, tagCards, byId);
      final shortSlot = kind.slots.any(
          (slot) => slot.options.every((o) => (tagCards[o.tag] ?? const []).isEmpty));
      final sample = PoolDealer(formula, copiesOf: copiesOf);
      boosters[kind.name] = BoosterPlay(
        packSize: sample.packSize,
        packCount: shortSlot || kind.slots.isEmpty ? 0 : sample.packCount,
        newSource: () => PoolDealer(formula, copiesOf: copiesOf),
      );
    }

    final placed = {
      for (final kind in pool.boosters)
        for (final slot in kind.slots)
          for (final option in slot.options)
            for (final card in tagCards[option.tag] ?? const <CardData>[]) card.id,
    };
    final sample = entries.isEmpty || pool.slots.isEmpty
        ? null
        : PoolDealer(poolFormula(pool, pool.slots, tagCards, byId), copiesOf: copiesOf);
    // The full formula's other variants reach every card of the set.
    final exactDefault = exactPool && exactTags && sameSlots(pool.slots, prefill.slots);
    return PlayPool(
      pool: pool,
      entries: entries,
      sets: sets,
      layoutSet: layoutSet,
      tagCards: tagCards,
      boosters: boosters,
      cardCount: entries.isEmpty ? 0 : sample?.cardCount,
      unplaced: exactDefault ? 0 : entries.length - placed.length,
    );
  }

  /// [pool] with tags and slots prefilled from its layout when it never
  /// had any (pools saved before tags existed).
  static Pool migrated(Pool pool, {required Map<String, CardSet> sets, required Iterable<CardData> cards}) {
    if (!pool.needsPrefill || cards.isEmpty) return pool;
    return switch (pool.layout) {
      BoosterLayout(:final setCode, :final booster) when sets[setCode] != null =>
        pool.prefilled(withCardsByRarity(prefillFromSet(sets[setCode]!, booster: booster), cards)),
      BoosterLayout() => pool.prefilled(prefillRandom(cards)),
      RandomLayout(:final packSize) => pool.prefilled(prefillRandom(cards, packSize: packSize)),
    };
  }

  /// Whether [pool]'s tags are [prefill]'s untouched.
  static bool sameTags(Pool pool, Prefill prefill) {
    if (pool.tags.length != prefill.tags.length) return false;
    for (final MapEntry(key: tag, value: def) in prefill.tags.entries) {
      final own = pool.tags[tag];
      if (own == null || own.cards.length != def.cards.length) return false;
      if (!own.cards.toSet().containsAll(def.cards)) return false;
    }
    return true;
  }

  static bool sameSlots(List<PackSlot> a, List<PackSlot> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Whether [pool]'s tags and default slots are [prefill] untouched.
  static bool samePrefill(Pool pool, Prefill prefill) =>
      sameTags(pool, prefill) && sameSlots(pool.slots, prefill.slots);

  final Pool pool;

  /// Distinct cards of the pool, for the editor.
  final List<PoolEntry> entries;

  /// The loaded sets of the pool's sources and layout, by code.
  final Map<String, CardSet> sets;

  /// The set the packs were prefilled from, when loaded.
  final CardSet? layoutSet;

  /// Every tag to the pool's cards carrying it (cards no longer in the
  /// pool left out).
  final Map<String, List<CardData>> tagCards;

  /// Each kind of booster, by name.
  final Map<String, BoosterPlay> boosters;

  /// Copies in the pool; `null` when some card is unlimited.
  final int? cardCount;

  /// Cards that fit no slot of any booster, so are never dealt.
  final int unplaced;

  String get name => pool.name;
  PoolConfig get config => pool.config;

  /// The default booster (the first one).
  BoosterPlay? get defaultBooster => boosters[pool.boosters.firstOrNull?.name];

  /// The booster called [name], else the default one.
  BoosterPlay? boosterPlay(String name) => boosters[name] ?? defaultBooster;

  int get packSize => defaultBooster?.packSize ?? 0;
  int? get packCount => switch (defaultBooster) { null => 0, final play => play.packCount };
  PackSource newSource() => (defaultBooster ?? (throw StateError('No booster'))).newSource();

  bool canDeal(int packs) => defaultBooster?.canDeal(packs) ?? false;

  /// Draft seats the pool can fill for [rounds] packs each (at most 8).
  int seatsFor(int rounds) => ((packCount ?? 8 * rounds) ~/ rounds).clamp(0, 8);

  /// Whether every booster of [format] can deal its packs for [players].
  bool canPlay(PlayFormat format, {int players = 1}) {
    if (format.rounds.isEmpty) return false;
    for (final MapEntry(key: name, value: packs) in format.packsPerPlayer.entries) {
      final play = boosterPlay(name);
      if (play == null || !play.canDeal(packs * players)) return false;
    }
    return true;
  }

  /// Draft seats the pool can fill for [format], at most its own.
  int seatsForFormat(PlayFormat format) {
    var seats = format.seats;
    for (final MapEntry(key: name, value: packs) in format.packsPerPlayer.entries) {
      final count = boosterPlay(name)?.packCount;
      if (count != null) seats = seats < count ~/ packs ? seats : count ~/ packs;
    }
    return seats.clamp(0, 8);
  }

  /// Every tag name, as the pool lists them.
  List<String> get tagNames => pool.tags.keys.toList();

  /// Every tag of one card.
  Set<String> tagsOfCard(String cardId) => pool.tagsOf(cardId).toSet();
}

/// The formula of one booster of [pool]: one sheet per tag (prefilled
/// weights, else the average of them, else listing), one slot per pack
/// slot of [slots].
BoosterFormula poolFormula(
  Pool pool,
  List<PackSlot> slots,
  Map<String, List<CardData>> tagCards,
  Map<String, PoolEntry> byId,
) {
  final sheets = <String, BoosterSheet>{
    for (final MapEntry(key: tag, value: def) in pool.tags.entries)
      tag: BoosterSheet(
        cards: tagCards[tag] ?? const [],
        weights: [for (final card in tagCards[tag] ?? const <CardData>[]) weightOf(def, card, byId)],
        foil: def.foil,
        balanceColors: def.balanceColors,
        allowDuplicates: def.allowDuplicates,
      ),
  };
  final contents = <String, int>{};
  for (final (i, slot) in slots.indexed) {
    final key = 'slot:$i';
    sheets[key] = slotSheet(slot, pool, tagCards, byId);
    contents[key] = slot.count;
  }
  return BoosterFormula(
    variants: [BoosterVariant(weight: 1, contents: contents)],
    sheets: sheets,
  );
}

/// A card's draw weight in [def]: its prefilled weight, else the average
/// prefilled weight, else how often it is listed.
int weightOf(TagDef def, CardData card, Map<String, PoolEntry> byId) {
  if (def.weights[card.id] case final w?) return w;
  if (def.weights.isNotEmpty) {
    return (def.weights.values.fold(0, (a, b) => a + b) / def.weights.length).round().clamp(1, 1 << 30);
  }
  return byId[card.id]?.listed ?? 1;
}

/// The sheet of a slot: the cards of every option, weighted so each
/// option's share of the draws follows its weight, and within an option
/// by its tag's weights. A card in two options counts once with both
/// shares. Flags come from the tags.
BoosterSheet slotSheet(
  PackSlot slot,
  Pool pool,
  Map<String, List<CardData>> tagCards,
  Map<String, PoolEntry> byId,
) {
  final weights = <CardData, int>{};
  var foil = false;
  var balanceColors = false;
  var allowDuplicates = false;
  for (final option in slot.options) {
    final cards = tagCards[option.tag] ?? const <CardData>[];
    final def = pool.tags[option.tag];
    if (cards.isEmpty || def == null) continue;
    foil = foil || def.foil;
    balanceColors = balanceColors || def.balanceColors;
    allowDuplicates = allowDuplicates || def.allowDuplicates;
    final total = cards.fold(0, (sum, card) => sum + weightOf(def, card, byId));
    for (final card in cards) {
      // Scaled so the option's cards weigh option.weight × 10000 together.
      final share = (option.weight * 10000 * weightOf(def, card, byId) / total).round().clamp(1, 1 << 30);
      weights.update(card, (w) => w + share, ifAbsent: () => share);
    }
  }
  return BoosterSheet(
    cards: weights.keys.toList(),
    weights: weights.values.toList(),
    foil: foil,
    balanceColors: balanceColors,
    allowDuplicates: allowDuplicates,
  );
}
