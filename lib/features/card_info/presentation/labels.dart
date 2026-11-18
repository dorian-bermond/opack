import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../catalog/domain/models.dart';
import '../domain/card_filter.dart';
import '../domain/card_info.dart';
import '../domain/pool_metrics.dart';
import '../../pools/domain/pool.dart';

String sortLabel(AppLocalizations l10n, CardSort sort) => switch (sort) {
      CardSort.name => l10n.sortName,
      CardSort.rarity => l10n.sortRarity,
      CardSort.manaValue => l10n.sortManaValue,
      CardSort.color => l10n.sortColor,
      CardSort.type => l10n.sortType,
      CardSort.power => l10n.sortPower,
      CardSort.toughness => l10n.sortToughness,
      CardSort.collector => l10n.sortCollector,
      CardSort.level => l10n.sortLevel,
      CardSort.atk => l10n.sortAtk,
      CardSort.def => l10n.sortDef,
      CardSort.attribute => l10n.sortAttribute,
      CardSort.race => l10n.sortRace,
      CardSort.archetype => l10n.sortArchetype,
      CardSort.cost => l10n.facetCost,
      CardSort.counter => l10n.facetCounter,
    };

String facetLabel(AppLocalizations l10n, Facet facet) => switch (facet) {
      Facet.rarity => l10n.facetRarity,
      Facet.color => l10n.facetColor,
      Facet.colorIdentity => l10n.facetColorIdentity,
      Facet.type => l10n.facetType,
      Facet.subtype => l10n.facetSubtype,
      Facet.keyword => l10n.facetKeyword,
      Facet.manaValue => l10n.facetManaValue,
      Facet.set => l10n.facetSet,
      Facet.kind => l10n.facetKind,
      Facet.category => l10n.facetCategory,
      Facet.attribute => l10n.facetAttribute,
      Facet.race => l10n.facetRace,
      Facet.property => l10n.facetProperty,
      Facet.archetype => l10n.facetArchetype,
      Facet.level => l10n.facetLevel,
      Facet.linkRating => l10n.facetLinkRating,
      Facet.atk => l10n.facetAtk,
      Facet.def => l10n.facetDef,
      Facet.tag => l10n.facetTag,
      Facet.quality => l10n.tierlistQuality,
      Facet.cost => l10n.facetCost,
      Facet.power => l10n.sortPower,
      Facet.counter => l10n.facetCounter,
    };

String metricLabel(AppLocalizations l10n, Metric metric) => switch (metric) {
      Metric.manaCurve => l10n.metricManaCurve,
      Metric.colors => l10n.metricColors,
      Metric.colorIdentity => l10n.metricColorIdentity,
      Metric.colorCount => l10n.metricColorCount,
      Metric.devotion => l10n.metricDevotion,
      Metric.types => l10n.metricTypes,
      Metric.subtypes => l10n.metricSubtypes,
      Metric.keywords => l10n.metricKeywords,
      Metric.creatureSize => l10n.metricCreatureSize,
      Metric.rarity => l10n.metricRarity,
      Metric.foil => l10n.metricFoil,
      Metric.sets => l10n.metricSets,
      Metric.kind => l10n.metricKind,
      Metric.categories => l10n.metricCategories,
      Metric.levels => l10n.metricLevels,
      Metric.ranks => l10n.metricRanks,
      Metric.linkRatings => l10n.metricLinkRatings,
      Metric.attributes => l10n.metricAttributes,
      Metric.races => l10n.metricRaces,
      Metric.atk => l10n.metricAtk,
      Metric.def => l10n.metricDef,
      Metric.archetypes => l10n.metricArchetypes,
      Metric.properties => l10n.metricProperties,
      Metric.tags => l10n.metricTags,
      Metric.costCurve => l10n.metricCostCurve,
      Metric.power => l10n.metricPower,
      Metric.counters => l10n.metricCounters,
      Metric.life => l10n.metricLife,
    };

/// A tag as the user reads it: rarity tags and the random slot localized,
/// built-in sheet names such as `foilCommon` spelled out, user tags as is.
String tagLabel(AppLocalizations l10n, String tag) {
  if (tag.startsWith('rarity:')) return '${l10n.facetRarity}: ${valueLabel(l10n, tag)}';
  if (tag.startsWith('$printedRarityQuality:')) return '${l10n.facetPrintedRarity}: ${valueLabel(l10n, tag)}';
  if (tag.indexOf(':') case final i when i > 0) {
    return '${qualityLabel(l10n, tag.substring(0, i))}: ${tagLabel(l10n, tag.substring(i + 1))}';
  }
  if (tag == 'pool' || Rarity.values.any((r) => r.name == tag)) return valueLabel(l10n, tag);
  if (!RegExp(r'^[a-z]+[A-Z]').hasMatch(tag)) return tag;
  final words = tag.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]!.toLowerCase()}');
  return words[0].toUpperCase() + words.substring(1);
}

/// A quality name as the user reads it: the rarity's own label, else the
/// name capitalized.
String qualityLabel(AppLocalizations l10n, String quality) => switch (quality) {
      'rarity' => l10n.facetRarity,
      printedRarityQuality => l10n.facetPrintedRarity,
      _ => quality.isEmpty ? quality : quality[0].toUpperCase() + quality.substring(1),
    };

/// One line of details under a card: cost and type line, or attribute,
/// monster type, level and ATK/DEF; `null` without details.
String? cardInfoLine(CardInfo? info) => switch (info) {
      OpcCardInfo(:final type, :final colors, :final cost, :final power, :final counter, :final life, :final attribute) => [
          [type, if (colors.isNotEmpty) colors.join('/')].join(' · '),
          if (cost != null) 'Cost $cost',
          if (life != null) 'Life $life',
          if (power != null) 'Power $power',
          if (counter != null && counter > 0) 'Counter +$counter',
          ?attribute,
        ].join(' · '),
      MtgCardInfo(:final manaCost, :final typeLine) => [?manaCost, typeLine].join(' · '),
      YgoCardInfo(kind: YgoKind.monster, :final attribute, :final race, :final level, :final linkRating, :final atk, :final def) =>
        [
          ?attribute,
          ?race,
          if (linkRating case final link?) 'LINK-$link' else if (level case final lvl?) '★$lvl',
          if (atk != null || def != null) 'ATK ${atk ?? '?'} / DEF ${def ?? '?'}',
        ].join(' · '),
      YgoCardInfo(:final type, :final race) => [type, ?race].join(' · '),
      null => null,
    };

/// A raw facet or metric value (`W`, `mono`, `spell:Quick-Play`, a rarity
/// name…) as the user reads it; most values are shown as they are.
String valueLabel(AppLocalizations l10n, String value) {
  if (value.isEmpty) return l10n.noArchetype;
  if (value == 'ø') return value;
  final rarity = Rarity.values.where((r) => r.name == value).firstOrNull;
  if (rarity != null) return rarity.label(l10n);
  if (value.startsWith('rarity:')) return valueLabel(l10n, value.substring(7));
  if (value.startsWith('$printedRarityQuality:')) return valueLabel(l10n, value.substring(printedRarityQuality.length + 1));
  if (value == 'pool') return l10n.allCards;
  if (value.contains(':')) {
    final [kind, property] = value.split(':');
    return '${valueLabel(l10n, kind)} · $property';
  }
  return switch (value) {
    'W' => l10n.colorWhite,
    'U' => l10n.colorBlue,
    'B' => l10n.colorBlack,
    'R' => l10n.colorRed,
    'G' => l10n.colorGreen,
    'C' || 'colorless' => l10n.colorless,
    'mono' => l10n.monoColored,
    'multi' => l10n.multiColored,
    'monster' => l10n.kindMonster,
    'spell' => l10n.kindSpell,
    'trap' => l10n.kindTrap,
    'foil' => l10n.foil,
    'nonfoil' => l10n.nonFoil,
    _ => value,
  };
}
