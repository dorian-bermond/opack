import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/packs/domain/pack_generator.dart';

import 'test_catalog.dart';

CardData _card(String id, {Rarity rarity = Rarity.common, String colors = ''}) =>
    CardData(id: id, names: {'en': id}, rarity: rarity, colors: colors);

void main() {
  group('formula rules', () {
    test('variant weights are respected', () {
      final common = BoosterSheet(cards: [_card('c')], weights: [1]);
      final rare = BoosterSheet(cards: [_card('r', rarity: Rarity.rare)], weights: [1]);
      final formula = BoosterFormula(
        variants: const [
          BoosterVariant(weight: 3, contents: {'common': 1}),
          BoosterVariant(weight: 1, contents: {'rare': 1}),
        ],
        sheets: {'common': common, 'rare': rare},
      );
      final generator = PackGenerator(formula, random: Random(1));
      final rares = List.generate(8000, (_) => generator.openPack().single)
          .where((c) => c.rarity == Rarity.rare)
          .length;
      expect(rares, inInclusiveRange(1800, 2200)); // expected 1 in 4
    });

    test('foil sheets mark cards foil, duplicates are avoided', () {
      final cards = List.generate(10, (i) => _card('c$i'));
      final formula = BoosterFormula(
        variants: const [BoosterVariant(weight: 1, contents: {'c': 8, 'f': 1})],
        sheets: {
          'c': BoosterSheet(cards: cards, weights: List.filled(10, 1)),
          'f': BoosterSheet(cards: cards, weights: List.filled(10, 1), foil: true),
        },
      );
      final generator = PackGenerator(formula, random: Random(2));
      for (var i = 0; i < 200; i++) {
        final pack = generator.openPack();
        final nonFoil = pack.where((c) => !c.foil).map((c) => c.id);
        expect(nonFoil.toSet(), hasLength(8));
        expect(pack.last.foil, isTrue);
      }
    });

    test('balanced sheets give one card of each color first', () {
      final cards = [
        for (final color in 'WUBRG'.split(''))
          for (var i = 0; i < 20; i++) _card('$color$i', colors: color),
      ];
      // Weight white heavily so an unbalanced draw would often miss colors.
      final weights = [for (final c in cards) c.colors == 'W' ? 50 : 1];
      final formula = BoosterFormula(
        variants: const [BoosterVariant(weight: 1, contents: {'c': 5})],
        sheets: {'c': BoosterSheet(cards: cards, weights: weights, balanceColors: true)},
      );
      final generator = PackGenerator(formula, random: Random(3));
      for (var i = 0; i < 100; i++) {
        expect(generator.openPack().map((c) => c.colors).toSet(), hasLength(5));
      }
    });
  });

  test('CIBR packs: 7 commons, 1 rare, 1 super/ultra/secret', () {
    final set = loadBundled('ygo/CIBR');
    final card = set.cards.singleWhere((c) => c.id == 'CIBR-FR077');
    expect(card.nameFor('fr'), 'À Forces Égales');
    expect(card.nameFor('en'), 'Evenly Matched');

    final generator = PackGenerator(set.booster(), random: Random(42));
    for (var i = 0; i < 300; i++) {
      final pack = generator.openPack();
      expect(pack, hasLength(9));
      expect(pack.where((c) => c.rarity == Rarity.common), hasLength(7));
      expect(pack.where((c) => c.rarity == Rarity.rare), hasLength(1));
      expect(
        [Rarity.superRare, Rarity.ultraRare, Rarity.secretRare],
        contains(pack.last.rarity),
      );
    }
  });

  test('the default booster type is the first the set offers', () {
    final set = loadBundled('mtg/DMU');
    expect(set.boosterType(), BoosterType.draft);
    expect(set.boosterType(BoosterType.collector), BoosterType.collector);
    expect(set.boosterType(BoosterType.play), BoosterType.draft, reason: 'DMU has no play booster');
    expect(set.booster(BoosterType.play), same(set.booster(BoosterType.draft)));
  });

  test('DMU draft boosters match MTGJSON pack sizes', () {
    final set = loadBundled('mtg/DMU');
    expect(set.nameFor('fr'), 'Dominaria Uni');
    final formula = set.booster(BoosterType.draft);
    final sizes = formula.variants.map((v) => v.size).toSet();
    final foilWeight = formula.variants
        .where((v) => v.contents.keys.any((s) => formula.sheets[s]!.foil))
        .fold(0, (sum, v) => sum + v.weight);
    final expected = 1200 * foilWeight / formula.totalWeight;
    final generator = PackGenerator(formula, random: Random(5));
    var foils = 0;
    for (var i = 0; i < 1200; i++) {
      final pack = generator.openPack();
      expect(sizes, contains(pack.length));
      expect(pack.where((c) => c.rarity == Rarity.rare || c.rarity == Rarity.mythic),
          isNotEmpty);
      if (pack.any((c) => c.foil)) foils++;
    }
    expect(foils, inInclusiveRange(expected * 0.75, expected * 1.25));
  });
}