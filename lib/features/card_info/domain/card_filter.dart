import '../../catalog/domain/models.dart';
import 'card_info.dart';

/// A card of a pool with the details downloaded for it, if any, and its
/// tags (built-in slots, rarity, the user's).
typedef CardWithInfo = ({CardData card, CardInfo? info, Set<String> tags});

/// A property cards can be filtered on. Categorical facets list one or more
/// values per card; numeric ones a number (cards without one never match a
/// range).
enum Facet {
  rarity,
  color,
  colorIdentity,
  type,
  subtype,
  keyword,
  manaValue(numeric: true),
  set,
  kind,
  category,
  attribute,
  race,
  property,
  archetype,
  level(numeric: true),
  linkRating(numeric: true),
  atk(numeric: true),
  def(numeric: true),
  cost(numeric: true),
  power(numeric: true),
  counter(numeric: true),
  tag,
  quality;

  const Facet({this.numeric = false});

  final bool numeric;

  static List<Facet> forGame(Game game) => switch (game) {
        Game.mtg => const [tag, quality, rarity, color, colorIdentity, type, subtype, keyword, manaValue, set],
        Game.ygo => const [tag, quality, rarity, kind, category, attribute, race, property, archetype, level, linkRating, atk, def, set],
        Game.opc => const [tag, quality, rarity, color, type, subtype, attribute, cost, power, counter, set],
      };

  /// The values a card has for this facet. Colors use `C` for colorless.
  Iterable<String> valuesOf(CardWithInfo item) {
    final (:card, :info, tags: _) = item;
    final mtg = info is MtgCardInfo ? info : null;
    final ygo = info is YgoCardInfo ? info : null;
    final opc = info is OpcCardInfo ? info : null;
    switch (this) {
      case Facet.rarity:
        return [card.rarity.name];
      case Facet.color:
        if (opc != null) return opc.colors;
        if (mtg == null) return const [];
        return mtg.colors.isEmpty ? const ['C'] : mtg.colors;
      case Facet.colorIdentity:
        if (mtg == null) return const [];
        return mtg.colorIdentity.isEmpty ? const ['C'] : mtg.colorIdentity;
      case Facet.type:
        return opc != null ? [opc.type] : mtg?.types ?? const [];
      case Facet.subtype:
        return opc?.subtypes ?? mtg?.subtypes ?? const [];
      case Facet.keyword:
        return mtg?.keywords ?? const [];
      case Facet.set:
        return [mtg?.setCode ?? ygo?.setName ?? opc?.setCode ?? card.id.split('-').first];
      case Facet.kind:
        return ygo == null ? const [] : [ygo.kind.name];
      case Facet.category:
        return ygo?.categories ?? const [];
      case Facet.attribute:
        return [?(ygo?.attribute ?? opc?.attribute)];
      case Facet.race:
        return ygo?.kind == YgoKind.monster ? [?ygo?.race] : const [];
      case Facet.property:
        return ygo != null && ygo.kind != YgoKind.monster ? [?ygo.race] : const [];
      case Facet.archetype:
        return ygo == null ? const [] : [ygo.archetype ?? ''];
      case Facet.tag:
        return [for (final t in item.tags) if (!t.contains(':')) t];
      case Facet.quality:
        // Values of every quality; ø when the card holds none.
        final values = [for (final t in item.tags) if (t.contains(':')) t];
        return values.isEmpty ? const ['ø'] : values;
      case Facet.manaValue:
      case Facet.level:
      case Facet.linkRating:
      case Facet.atk:
      case Facet.def:
      case Facet.cost:
      case Facet.power:
      case Facet.counter:
        return const [];
    }
  }

  num? numberOf(CardWithInfo item) {
    final info = item.info;
    final mtg = info is MtgCardInfo ? info : null;
    final ygo = info is YgoCardInfo ? info : null;
    final opc = info is OpcCardInfo ? info : null;
    return switch (this) {
      Facet.manaValue => mtg?.manaValue,
      Facet.cost => opc?.cost,
      Facet.power => opc?.power,
      Facet.counter => opc?.counter,
      Facet.level => ygo?.level,
      Facet.linkRating => ygo?.linkRating,
      Facet.atk => ygo?.atk,
      Facet.def => ygo?.def,
      _ => null,
    };
  }
}

/// Which cards of a pool to show: chosen values per facet (a card matches
/// when it has one of them) and number ranges, all combined.
class CardFilter {
  const CardFilter({this.chosen = const {}, this.ranges = const {}});

  final Map<Facet, Set<String>> chosen;
  final Map<Facet, (num, num)> ranges;

  bool get isEmpty => chosen.values.every((v) => v.isEmpty) && ranges.isEmpty;

  int get activeCount => chosen.values.where((v) => v.isNotEmpty).length + ranges.length;

  bool matches(CardWithInfo item) {
    for (final MapEntry(key: facet, value: wanted) in chosen.entries) {
      if (wanted.isNotEmpty && !facet.valuesOf(item).any(wanted.contains)) return false;
    }
    for (final MapEntry(key: facet, value: (min, max)) in ranges.entries) {
      final value = facet.numberOf(item);
      if (value == null || value < min || value > max) return false;
    }
    return true;
  }

  CardFilter toggle(Facet facet, String value) {
    final values = {...?chosen[facet]};
    values.contains(value) ? values.remove(value) : values.add(value);
    return CardFilter(chosen: {...chosen, facet: values}, ranges: ranges);
  }

  /// Keeps only cards whose value lies in [range]; `null` lifts the range.
  CardFilter withRange(Facet facet, (num, num)? range) => CardFilter(
        chosen: chosen,
        ranges: {
          for (final MapEntry(:key, :value) in ranges.entries)
            if (key != facet) key: value,
          facet: ?range,
        },
      );
}

/// Orders of a pool's card list.
enum CardSort {
  name,
  rarity,
  manaValue,
  color,
  type,
  power,
  toughness,
  collector,
  level,
  atk,
  def,
  attribute,
  race,
  archetype,
  cost,
  counter;

  static List<CardSort> forGame(Game game) => switch (game) {
        Game.mtg => const [name, rarity, manaValue, color, type, power, toughness, collector],
        Game.ygo => const [name, rarity, level, atk, def, attribute, race, archetype, collector],
        Game.opc => const [name, rarity, cost, power, counter, color, type, attribute, collector],
      };

  /// Compares two cards; ties fall back to rarity (highest first) then name.
  int compare(CardWithInfo a, CardWithInfo b, String language) {
    final primary = switch (this) {
      name => 0,
      rarity => _desc(a.card.rarity.index, b.card.rarity.index),
      manaValue => _num(_mtg(a)?.manaValue, _mtg(b)?.manaValue),
      color => _text(_colorKey(_mtg(a)) ?? _opcColorKey(_opc(a)), _colorKey(_mtg(b)) ?? _opcColorKey(_opc(b))),
      type => _text(_mtg(a)?.types.join(' ') ?? _opc(a)?.type, _mtg(b)?.types.join(' ') ?? _opc(b)?.type),
      power => _desc(_mtg(a)?.powerValue ?? _opc(a)?.power, _mtg(b)?.powerValue ?? _opc(b)?.power),
      toughness => _desc(_mtg(a)?.toughnessValue, _mtg(b)?.toughnessValue),
      collector => _collector(a.card.id).compareTo(_collector(b.card.id)),
      level => _desc(_ygo(a)?.level, _ygo(b)?.level),
      atk => _desc(_ygo(a)?.atk, _ygo(b)?.atk),
      def => _desc(_ygo(a)?.def, _ygo(b)?.def),
      attribute => _text(_ygo(a)?.attribute ?? _opc(a)?.attribute, _ygo(b)?.attribute ?? _opc(b)?.attribute),
      cost => _num(_opc(a)?.cost, _opc(b)?.cost),
      counter => _desc(_opc(a)?.counter, _opc(b)?.counter),
      race => _text(_ygo(a)?.race, _ygo(b)?.race),
      archetype => _text(_ygo(a)?.archetype, _ygo(b)?.archetype),
    };
    if (primary != 0) return primary;
    if (this != rarity) {
      final byRarity = b.card.rarity.index.compareTo(a.card.rarity.index);
      if (byRarity != 0) return byRarity;
    }
    return a.card.nameFor(language).toLowerCase().compareTo(b.card.nameFor(language).toLowerCase());
  }

  static MtgCardInfo? _mtg(CardWithInfo item) => item.info is MtgCardInfo ? item.info as MtgCardInfo : null;
  static YgoCardInfo? _ygo(CardWithInfo item) => item.info is YgoCardInfo ? item.info as YgoCardInfo : null;
  static OpcCardInfo? _opc(CardWithInfo item) => item.info is OpcCardInfo ? item.info as OpcCardInfo : null;

  /// One Piece colors in the game's order, multicolor after.
  static String? _opcColorKey(OpcCardInfo? info) {
    if (info == null) return null;
    if (info.colors.isEmpty) return '9';
    if (info.colors.length > 1) return '8${info.colors.map(opcColors.indexOf).join()}';
    return '${opcColors.indexOf(info.colors.single)}';
  }

  /// Ascending, unknown values last.
  static int _num(num? a, num? b) => switch ((a, b)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final x?, final y?) => x.compareTo(y),
      };

  /// Descending, unknown values last.
  static int _desc(num? a, num? b) => switch ((a, b)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final x?, final y?) => y.compareTo(x),
      };

  static int _text(String? a, String? b) => switch ((a, b)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final x?, final y?) => x.compareTo(y),
      };

  /// WUBRG order, then multicolor, then colorless.
  static String? _colorKey(MtgCardInfo? info) {
    if (info == null) return null;
    const order = 'WUBRG';
    final colors = info.colors;
    if (colors.isEmpty) return '7';
    if (colors.length > 1) return '6${colors.map(order.indexOf).join()}';
    return '${order.indexOf(colors.single)}';
  }

  /// `DMU-12a` sorts by its number, then its letters.
  static (int, String) _collector(String id) {
    final number = id.split('-').skip(1).join('-');
    final digits = RegExp(r'\d+').firstMatch(number)?.group(0);
    return (int.tryParse(digits ?? '') ?? 1 << 30, number);
  }
}

extension on (int, String) {
  int compareTo((int, String) other) {
    final byNumber = $1.compareTo(other.$1);
    return byNumber != 0 ? byNumber : $2.compareTo(other.$2);
  }
}
