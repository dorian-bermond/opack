import 'dart:math';

import '../../catalog/domain/models.dart';
import 'pack_source.dart';

/// Unlimited copies of a card.
const unlimited = null;

/// Deals boosters from a pool where each card has its own number of copies,
/// [unlimited] (`null`) or finite. Every slot of the pack layout (commons,
/// rare, foil...) draws from the copies left, so a slot whose cards are all
/// limited caps the number of packs.
///
/// Uses the formula's most common pack layout. Cards are grouped by the
/// slots they can fill; [packCount] is the largest number of packs for which
/// every group of slots still has enough copies (Hall's condition), and each
/// draw keeps that true, so all [packCount] packs are always complete.
class PoolDealer implements PackSource {
  PoolDealer(
    BoosterFormula formula, {
    required int? Function(CardData card) copiesOf,
    Random? random,
  }) : _random = random ?? Random() {
    final variant = mainVariant(formula);
    for (final MapEntry(key: name, value: count) in variant.contents.entries) {
      final sheet = formula.sheets[name];
      if (sheet == null || sheet.cards.isEmpty || count <= 0) continue;
      _sheets.add(sheet);
      _counts.add(count);
    }

    final masks = <CardData, int>{};
    for (var s = 0; s < _sheets.length; s++) {
      final sheet = _sheets[s];
      for (var i = 0; i < sheet.cards.length; i++) {
        if (sheet.weights[i] > 0) {
          masks.update(sheet.cards[i], (m) => m | 1 << s, ifAbsent: () => 1 << s);
        }
      }
    }
    final groups = <int, int>{};
    for (final MapEntry(key: card, value: mask) in masks.entries) {
      final copies = copiesOf(card);
      if (copies == 0) continue;
      _stock[card] = copies;
      final group = groups.putIfAbsent(mask, () {
        _groupMasks.add(mask);
        _supply.add(0);
        return _groupMasks.length - 1;
      });
      _groupOf[card] = group;
      _supply[group] += copies ?? _infinite;
    }

    var packs = _sheets.isEmpty ? 0 : _infinite;
    for (var subset = 1; subset < 1 << _sheets.length; subset++) {
      packs = min(packs, _supplyFor(subset) ~/ _sum(subset, (s) => _counts[s]));
    }
    packCount = packs >= _infinite ~/ 1000 ? null : packs;
    _needs = [for (final count in _counts) count * (packCount ?? 0)];
  }

  /// Stands for an endless supply in the counts below.
  static const _infinite = 1 << 50;

  /// The layout used for every pack: the formula's most likely variant.
  static BoosterVariant mainVariant(BoosterFormula formula) =>
      formula.variants.reduce((a, b) => b.weight > a.weight ? b : a);

  final Random _random;

  /// Packs the pool can deal, or `null` without limit.
  late final int? packCount;

  final _sheets = <BoosterSheet>[];
  final _counts = <int>[];
  final _stock = <CardData, int?>{};
  final _groupOf = <CardData, int>{};
  final _groupMasks = <int>[];
  final _supply = <int>[];

  /// Cards each slot still has to receive over the remaining packs (only
  /// tracked when [packCount] is finite).
  late final List<int> _needs;
  int _dealt = 0;

  int get packSize => _counts.fold(0, (a, b) => a + b);

  /// Copies in the pool, or `null` when a card is unlimited.
  int? get cardCount => _stock.values.contains(unlimited)
      ? null
      : _stock.values.fold<int>(0, (a, b) => a + b!);

  @override
  List<CardData> nextPack() {
    if (packCount case final packs? when _dealt >= packs) {
      throw StateError('Pool exhausted after $packs packs');
    }
    final pack = <CardData>[];
    for (var s = 0; s < _sheets.length; s++) {
      final drawn = <CardData>[];
      for (var n = 0; n < _counts[s]; n++) {
        drawn.add(_draw(s, pack.followedBy(drawn).toSet()));
      }
      pack.addAll(_sheets[s].foil ? drawn.map((c) => c.asFoil()) : drawn);
    }
    _dealt++;
    return pack;
  }

  CardData _draw(int s, Set<CardData> inPack) {
    final sheet = _sheets[s];
    final blocked = <int>{};
    while (true) {
      bool available(int i) {
        final card = sheet.cards[i];
        final group = _groupOf[card];
        return sheet.weights[i] > 0 &&
            group != null &&
            _stock[card] != 0 &&
            !blocked.contains(group);
      }

      final index =
          _weightedIndex(sheet, (i) => available(i) && !inPack.contains(sheet.cards[i])) ??
              _weightedIndex(sheet, available);
      if (index == null) throw StateError('Slot ${s + 1} has no card left');

      final card = sheet.cards[index];
      final copies = _stock[card];
      if (copies == null) return card; // unlimited
      // Without a pack limit every slot has unlimited cards to fall back on.
      if (packCount == null) {
        _stock[card] = copies - 1;
        return card;
      }

      final group = _groupOf[card]!;
      _supply[group]--;
      _needs[s]--;
      if (_feasible()) {
        _stock[card] = copies - 1;
        return card;
      }
      _supply[group]++;
      _needs[s]++;
      blocked.add(group);
    }
  }

  /// Every set of slots can still be filled from the copies they accept.
  bool _feasible() {
    for (var subset = 1; subset < 1 << _sheets.length; subset++) {
      if (_sum(subset, (s) => _needs[s]) > _supplyFor(subset)) return false;
    }
    return true;
  }

  int _supplyFor(int subset) {
    var total = 0;
    for (var g = 0; g < _groupMasks.length; g++) {
      if (_groupMasks[g] & subset != 0) total += _supply[g];
    }
    return total;
  }

  int _sum(int subset, int Function(int) value) {
    var total = 0;
    for (var s = 0; s < _sheets.length; s++) {
      if (subset & 1 << s != 0) total += value(s);
    }
    return total;
  }

  int? _weightedIndex(BoosterSheet sheet, bool Function(int) allowed) {
    var total = 0;
    for (var i = 0; i < sheet.cards.length; i++) {
      if (allowed(i)) total += sheet.weights[i];
    }
    if (total == 0) return null;
    var roll = _random.nextInt(total);
    for (var i = 0; i < sheet.cards.length; i++) {
      if (!allowed(i)) continue;
      if (roll < sheet.weights[i]) return i;
      roll -= sheet.weights[i];
    }
    return null;
  }
}
