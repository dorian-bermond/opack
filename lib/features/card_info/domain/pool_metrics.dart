import '../../catalog/domain/models.dart';
import 'card_filter.dart';
import 'card_info.dart';

/// A breakdown of a pool's cards. Rows are `(label, count)`, labels being
/// raw values (`W`, `Creature`, `DARK`…) the UI may localize.
enum Metric {
  manaCurve,
  colors,
  colorIdentity,
  colorCount,
  devotion,
  types,
  subtypes,
  keywords,
  creatureSize,
  rarity,
  foil,
  sets,
  kind,
  categories,
  levels,
  ranks,
  linkRatings,
  attributes,
  races,
  atk,
  def,
  archetypes,
  properties,
  tags,
  costCurve,
  power,
  counters,
  life,
}

class MetricSection {
  const MetricSection(this.metric, this.rows, {this.average, this.max, this.known});

  final Metric metric;
  final List<(String, int)> rows;

  /// A mean over the cards that have the value (mana value, ATK…).
  final double? average;

  /// The highest value seen.
  final num? max;

  /// How many cards had the value, when fewer than all (e.g. creatures).
  final int? known;

  bool get isEmpty => rows.isEmpty;
}

/// Every metric of [game] over [cards], skipping empty ones. Cards without
/// downloaded details only count in rarity, foil and set breakdowns.
List<MetricSection> poolMetrics(Game game, List<CardWithInfo> cards) {
  final sections = switch (game) {
    Game.mtg => _mtg(cards),
    Game.ygo => _ygo(cards),
    Game.opc => _opc(cards),
  };
  return [for (final section in sections) if (!section.isEmpty) section];
}

List<MetricSection> _mtg(List<CardWithInfo> cards) {
  final infos = [for (final c in cards) if (c.info case final MtgCardInfo info) info];
  final creatures = infos.where((i) => i.types.contains('Creature')).toList();
  final sized = creatures.where((i) => i.powerValue != null && i.toughnessValue != null).toList();
  return [
    MetricSection(
      Metric.manaCurve,
      _ordered([for (final i in infos) i.manaValue >= 7 ? '7+' : '${i.manaValue.toInt()}'],
          order: ['0', '1', '2', '3', '4', '5', '6', '7+']),
      average: _mean([for (final i in infos) i.manaValue]),
    ),
    MetricSection(
      Metric.colors,
      _ordered([for (final i in infos) ...(i.colors.isEmpty ? const ['C'] : i.colors)],
          order: const ['W', 'U', 'B', 'R', 'G', 'C']),
    ),
    MetricSection(
      Metric.colorIdentity,
      _ordered([for (final i in infos) ...(i.colorIdentity.isEmpty ? const ['C'] : i.colorIdentity)],
          order: const ['W', 'U', 'B', 'R', 'G', 'C']),
    ),
    MetricSection(
      Metric.colorCount,
      _ordered([
        for (final i in infos)
          i.colors.isEmpty
              ? 'colorless'
              : i.colors.length == 1
                  ? 'mono'
                  : 'multi',
      ], order: const ['mono', 'multi', 'colorless']),
    ),
    MetricSection(
      Metric.devotion,
      _ordered([
        for (final i in infos)
          for (final MapEntry(key: color, value: pips) in i.pips.entries)
            for (var p = 0; p < pips; p++) color,
      ], order: const ['W', 'U', 'B', 'R', 'G']),
    ),
    MetricSection(Metric.types, _counted([for (final i in infos) ...i.types])),
    MetricSection(Metric.subtypes, _counted([for (final i in infos) ...i.subtypes], top: 12)),
    MetricSection(Metric.keywords, _counted([for (final i in infos) ...i.keywords], top: 15)),
    MetricSection(
      Metric.creatureSize,
      _ordered([
        for (final i in sized) '${i.powerValue}/${i.toughnessValue}',
      ], order: const []),
      average: _mean([for (final i in sized) i.powerValue!.toDouble()]),
      max: sized.isEmpty ? null : sized.map((i) => i.powerValue!).reduce((a, b) => a > b ? a : b),
      known: sized.length,
    ),
    ..._common(cards),
    MetricSection(
        Metric.sets, _counted([for (final c in cards) (c.info as MtgCardInfo?)?.setCode ?? c.card.id.split('-').first])),
  ];
}

List<MetricSection> _ygo(List<CardWithInfo> cards) {
  final infos = [for (final c in cards) if (c.info case final YgoCardInfo info) info];
  final monsters = infos.where((i) => i.kind == YgoKind.monster).toList();
  final withAtk = monsters.where((i) => i.atk != null).toList();
  final withDef = monsters.where((i) => i.def != null).toList();
  return [
    MetricSection(Metric.kind, _ordered([for (final i in infos) i.kind.name], order: const ['monster', 'spell', 'trap'])),
    MetricSection(Metric.categories, _ordered([for (final i in monsters) ...i.categories], order: ygoCategories)),
    MetricSection(
      Metric.levels,
      _ordered([for (final i in monsters) if (!i.isXyz && !i.isLink && i.level != null) '${i.level}'],
          order: [for (var l = 0; l <= 12; l++) '$l']),
    ),
    MetricSection(
      Metric.ranks,
      _ordered([for (final i in monsters) if (i.isXyz && i.level != null) '${i.level}'],
          order: [for (var l = 0; l <= 13; l++) '$l']),
    ),
    MetricSection(
      Metric.linkRatings,
      _ordered([for (final i in monsters) if (i.linkRating != null) '${i.linkRating}'],
          order: [for (var l = 1; l <= 6; l++) '$l']),
    ),
    MetricSection(Metric.attributes, _counted([for (final i in monsters) ?i.attribute])),
    MetricSection(Metric.races, _counted([for (final i in monsters) ?i.race])),
    MetricSection(
      Metric.atk,
      _ordered([for (final i in withAtk) _bucket(i.atk!)], order: _buckets),
      average: _mean([for (final i in withAtk) i.atk!.toDouble()]),
      max: withAtk.isEmpty ? null : withAtk.map((i) => i.atk!).reduce((a, b) => a > b ? a : b),
      known: withAtk.length,
    ),
    MetricSection(
      Metric.def,
      _ordered([for (final i in withDef) _bucket(i.def!)], order: _buckets),
      average: _mean([for (final i in withDef) i.def!.toDouble()]),
      max: withDef.isEmpty ? null : withDef.map((i) => i.def!).reduce((a, b) => a > b ? a : b),
      known: withDef.length,
    ),
    MetricSection(Metric.archetypes, _counted([for (final i in infos) i.archetype ?? ''], top: 15)),
    MetricSection(
      Metric.properties,
      _counted([for (final i in infos) if (i.kind != YgoKind.monster && i.race != null) '${i.kind.name}:${i.race}']),
    ),
    ..._common(cards),
    MetricSection(
      Metric.sets,
      _counted([for (final c in cards) (c.info as YgoCardInfo?)?.setName ?? c.card.id.split('-').first]),
    ),
  ];
}

List<MetricSection> _opc(List<CardWithInfo> cards) {
  final infos = [for (final c in cards) if (c.info case final OpcCardInfo info) info];
  final withCost = infos.where((i) => i.cost != null && i.type != 'Leader').toList();
  final withPower = infos.where((i) => i.power != null).toList();
  final withCounter = infos.where((i) => i.counter != null && i.counter! > 0).toList();
  final leaders = infos.where((i) => i.type == 'Leader' && i.life != null).toList();
  return [
    MetricSection(
      Metric.costCurve,
      _ordered([for (final i in withCost) i.cost! >= 8 ? '8+' : '${i.cost}'],
          order: ['0', '1', '2', '3', '4', '5', '6', '7', '8+']),
      average: _mean([for (final i in withCost) i.cost!.toDouble()]),
      known: withCost.length,
    ),
    MetricSection(Metric.colors, _ordered([for (final i in infos) ...i.colors], order: opcColors)),
    MetricSection(
      Metric.colorCount,
      _ordered([for (final i in infos) i.colors.length > 1 ? 'multi' : 'mono'], order: const ['mono', 'multi']),
    ),
    MetricSection(Metric.types, _ordered([for (final i in infos) i.type], order: opcTypes)),
    MetricSection(Metric.subtypes, _counted([for (final i in infos) ...i.subtypes], top: 15)),
    MetricSection(Metric.attributes, _counted([for (final i in infos) ?i.attribute])),
    MetricSection(
      Metric.power,
      _ordered([for (final i in withPower) '${i.power}'],
          order: [for (var p = 0; p <= 13000; p += 1000) '$p']),
      average: _mean([for (final i in withPower) i.power!.toDouble()]),
      max: withPower.isEmpty ? null : withPower.map((i) => i.power!).reduce((a, b) => a > b ? a : b),
      known: withPower.length,
    ),
    MetricSection(
      Metric.counters,
      _ordered([for (final i in withCounter) '${i.counter}'], order: const ['1000', '2000']),
      known: withCounter.length,
    ),
    MetricSection(Metric.life, _counted([for (final i in leaders) '${i.life}'])),
    ..._common(cards),
    MetricSection(
      Metric.sets,
      _counted([for (final c in cards) (c.info as OpcCardInfo?)?.setName ?? c.card.id.split('-').first]),
    ),
  ];
}

List<MetricSection> _common(List<CardWithInfo> cards) => [
      MetricSection(
        Metric.rarity,
        _ordered([for (final c in cards) c.card.rarity.name],
            order: [for (final r in Rarity.values.reversed) r.name]),
      ),
      MetricSection(
        Metric.foil,
        _ordered([for (final c in cards) c.card.foil ? 'foil' : 'nonfoil'], order: const ['foil', 'nonfoil']),
      ),
      MetricSection(
        Metric.tags,
        _counted([for (final c in cards) ...c.tags.where((t) => !t.startsWith('rarity:'))]),
      ),
    ];

const _buckets = ['0-999', '1000-1999', '2000-2499', '2500-2999', '3000+'];

String _bucket(int value) => value < 1000
    ? '0-999'
    : value < 2000
        ? '1000-1999'
        : value < 2500
            ? '2000-2499'
            : value < 3000
                ? '2500-2999'
                : '3000+';

double? _mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

/// Counts in [order] (missing ones at 0 are dropped; unknown labels follow,
/// by count).
List<(String, int)> _ordered(List<String> labels, {required List<String> order}) {
  final counts = <String, int>{};
  for (final label in labels) {
    counts.update(label, (n) => n + 1, ifAbsent: () => 1);
  }
  final rest = counts.keys.where((k) => !order.contains(k)).toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return [
    for (final label in order)
      if (counts[label] case final n?) (label, n),
    for (final label in rest) (label, counts[label]!),
  ];
}

/// Counts by frequency, the [top] most frequent only when given.
List<(String, int)> _counted(List<String> labels, {int? top}) {
  final counts = <String, int>{};
  for (final label in labels) {
    counts.update(label, (n) => n + 1, ifAbsent: () => 1);
  }
  final rows = counts.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) {
      final byCount = b.$2.compareTo(a.$2);
      return byCount != 0 ? byCount : a.$1.compareTo(b.$1);
    });
  return top == null ? rows : rows.take(top).toList();
}
