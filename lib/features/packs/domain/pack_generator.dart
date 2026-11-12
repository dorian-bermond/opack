import 'dart:math';

import '../../catalog/domain/models.dart';
import 'pack_source.dart';

class PackGenerator implements PackSource {
  PackGenerator(this.formula, {Random? random}) : _random = random ?? Random();

  final BoosterFormula formula;
  final Random _random;

  @override
  List<CardData> nextPack() => openPack();

  /// Builds one booster: picks a weighted variant, then draws each sheet's
  /// cards. Sheets without `allowDuplicates` never repeat a card in a pack.
  List<CardData> openPack() {
    final variant = _pickVariant();
    final pack = <CardData>[];
    for (final MapEntry(key: name, value: count) in variant.contents.entries) {
      final sheet = formula.sheets[name];
      if (sheet == null || sheet.cards.isEmpty) continue;
      final drawn = _draw(sheet, count);
      pack.addAll(sheet.foil ? drawn.map((c) => c.asFoil()) : drawn);
    }
    return pack;
  }

  List<List<CardData>> openPacks(int count) =>
      List.generate(count, (_) => openPack());

  BoosterVariant _pickVariant() {
    var roll = _random.nextInt(formula.totalWeight);
    for (final variant in formula.variants) {
      if (roll < variant.weight) return variant;
      roll -= variant.weight;
    }
    return formula.variants.last;
  }

  List<CardData> _draw(BoosterSheet sheet, int count) {
    final taken = <int>{};
    final drawn = <CardData>[];

    void take(int index) {
      taken.add(index);
      drawn.add(sheet.cards[index]);
    }

    // Color balance: start with one card of each color when possible
    // (MTGJSON applies this to commons when 5+ are drawn).
    if (sheet.balanceColors && count >= 5) {
      for (final color in 'WUBRG'.split('')) {
        final index = _weightedIndex(
          sheet,
          (i) => !taken.contains(i) && sheet.cards[i].colors.contains(color),
        );
        if (index != null) take(index);
      }
    }

    while (drawn.length < count) {
      final index = _weightedIndex(
            sheet,
            (i) => sheet.allowDuplicates || !taken.contains(i),
          ) ??
          // Sheet exhausted: allow repeats rather than a short pack.
          _weightedIndex(sheet, (_) => true)!;
      take(index);
    }
    return drawn;
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
