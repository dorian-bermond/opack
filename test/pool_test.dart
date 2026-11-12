import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/cube/domain/cube.dart';
import 'package:opack/features/packs/domain/pack_generator.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/features/pools/domain/pool_config.dart';
import 'package:opack/features/packs/domain/pool_dealer.dart';

import 'test_catalog.dart';

void main() {
  List<CardData> cards(int count, {String prefix = '', Rarity rarity = Rarity.common}) =>
      List.generate(
        count,
        (i) => CardData(id: '$prefix$i', names: {'en': 'Card $prefix$i'}, rarity: rarity),
      );

  Cube cube(List<CardData> cards) => Cube(
        id: 'c',
        game: Game.mtg,
        name: 'Test',
        source: 'test',
        importedAt: DateTime(2026),
        cards: cards,
      );

  BoosterSheet sheet(List<CardData> cards, {bool foil = false}) =>
      BoosterSheet(cards: cards, weights: List.filled(cards.length, 1), foil: foil);

  final commons = cards(150);
  final rares = cards(30, prefix: 'r', rarity: Rarity.rare);
  final formula = BoosterFormula(
    variants: [const BoosterVariant(weight: 1, contents: {'common': 10, 'rare': 1})],
    sheets: {'common': sheet(commons), 'rare': sheet(rares)},
  );

  test('an empty pool deals nothing until a source is added', () {
    final empty = Pool.empty(Game.mtg, name: 'Mine');
    expect(empty.sources, isEmpty);
    expect(empty.layout, const RandomLayout());

    final play = PlayPool.resolve(empty, sets: const {}, cubes: const {});
    expect(play.entries, isEmpty);
    expect(play.packCount, 0);
    expect(play.canDeal(1), isFalse);
    expect(play.seatsFor(3), 0);
    expect(play.newSource, throwsStateError);

    final filled = empty.withSource(const CubeSource('c'));
    final playable = PlayPool.resolve(filled, sets: const {}, cubes: {'c': cube(cards(45))});
    expect(playable.packCount, 3);
    expect(playable.newSource().nextPack(), hasLength(15));

    // Removing the last source empties the pool again rather than failing.
    expect(filled.withoutSource(const CubeSource('c')).sources, isEmpty);
  });

  test('picked cards are a source of their own, saved with the pool', () {
    final picked = const CardsSource([]).plus(cards(3, prefix: 'p'));
    expect(picked.plus(cards(4, prefix: 'p')).cards, hasLength(4), reason: 'already picked prints are skipped');
    final pool = Pool.empty(Game.mtg, name: 'Mine').withSource(picked);
    final back = Pool.fromJson(jsonDecode(jsonEncode(pool.toJson())) as Map<String, dynamic>);
    expect(back.sources.single, isA<CardsSource>());
    expect((back.sources.single as CardsSource).cards.map((c) => c.id), ['p0', 'p1', 'p2']);
    final play = PlayPool.resolve(back, sets: const {}, cubes: const {});
    expect(play.entries, hasLength(3));
    expect(play.packCount, 0, reason: 'fewer cards than a pack');
  });

  test('a set only prefills tags and slots; all of them are the user\'s', () {
    final set = loadBundled('ygo/CIBR');
    final pool = Pool.ofSet(set, name: 'CIBR');
    expect(pool.slots.map((s) => s.options.single.tag), ['common', 'rare', 'superRare']);
    expect(pool.tags.keys, containsAll(['common', 'rare', 'superRare', 'rarity:common']));
    expect(pool.tags['common']!.weights, isNotEmpty);
    final back = Pool.fromJson(jsonDecode(jsonEncode(pool)) as Map<String, dynamic>);
    expect(back.tags['common']!.cards, pool.tags['common']!.cards);
    expect(PlayPool.samePrefill(back, prefillFromSet(set)), isTrue);

    // Untouched, an open set pool deals with the set's exact formula.
    final exact = PlayPool.resolve(back, sets: {'CIBR': set}, cubes: const {});
    expect(exact.packCount, isNull);
    expect(exact.packSize, 9);

    // Editing a tag or a slot: the pool's own data deals, like any other.
    final commons = pool.tags['common']!.cards;
    final rare = pool.tags['rare']!.cards.first;
    final edited = pool.withTag('common', [...commons.skip(1), rare]);
    expect(PlayPool.samePrefill(edited, prefillFromSet(set)), isFalse);
    final play = PlayPool.resolve(edited, sets: {'CIBR': set}, cubes: const {});
    expect(play.tagCards['common']!.map((c) => c.id), contains(rare));
    expect(play.tagCards['common']!.map((c) => c.id), isNot(contains(commons.first)));
    expect(play.tagsOfCard(rare), containsAll(['common', 'rare', 'rarity:rare']));
    final source = play.newSource();
    for (var i = 0; i < 300; i++) {
      expect(source.nextPack().any((c) => c.id == commons.first), isFalse);
    }

    // Deleting the common tag drops its slot: packs shrink to two cards.
    final noCommons = pool.withoutTag('common');
    expect(noCommons.slots, hasLength(2));
    expect(PlayPool.resolve(noCommons, sets: {'CIBR': set}, cubes: const {}).packSize, 2);
  });

  test('older pools without tags take their layout\'s prefill', () {
    final set = loadBundled('ygo/CIBR');
    final old = Pool(
      id: 'old',
      game: Game.ygo,
      name: 'Old',
      sources: const [SetSource('CIBR')],
      layout: const BoosterLayout('CIBR'),
      config: const PoolConfig.open(),
      updatedAt: DateTime(2026),
    );
    expect(old.needsPrefill, isTrue);
    final play = PlayPool.resolve(old, sets: {'CIBR': set}, cubes: const {});
    expect(play.pool.slots, isNotEmpty);
    expect(play.packSize, 9);
  });

  test('slots pull from tags, with weighted options', () {
    final deck = cube([...cards(60), ...cards(10, prefix: 'r', rarity: Rarity.rare)]);
    final base = Pool.ofCube(deck).prefilled(prefillRandom(deck.cards, packSize: 5));
    expect(base.slots.single, PackSlot.single(allCardsTag, 5));
    final tagged = base.withTag('fixing', ['r0', 'r1', 'r2', 'r3', 'r4']);
    expect(tagged.tagsOf('r0'), containsAll(['all', 'rarity:rare', 'fixing']));

    // One extra card from the tag on top of the 5 random ones.
    final extra = tagged.copyWith(slots: [...tagged.slots, PackSlot.single('fixing', 1)]);
    final play = PlayPool.resolve(extra, sets: const {}, cubes: {'c': deck});
    expect(play.packSize, 6);
    expect(play.packCount, 5, reason: 'five tagged cards, one per pack');
    final pack = play.newSource().nextPack();
    expect(pack, hasLength(6));
    expect(pack.where((c) => c.id.startsWith('r')), isNotEmpty);

    // Only the user's slot: packs are that slot alone.
    final only = extra.copyWith(slots: [PackSlot.single('fixing', 1)]);
    final custom = PlayPool.resolve(only, sets: const {}, cubes: {'c': deck});
    expect(custom.packSize, 1);
    expect(custom.newSource().nextPack().single.id, startsWith('r'));
    expect(custom.unplaced, 65);

    // A slot on a tag without cards deals nothing; dropping the tag drops it.
    final short = extra.copyWith(slots: [PackSlot.single('nothing', 1)]);
    expect(PlayPool.resolve(short, sets: const {}, cubes: {'c': deck}).packCount, 0);
    expect(extra.withoutTag('fixing').slots, hasLength(1));

    // A rarity tag works like any other.
    final rares = base.copyWith(slots: [...base.slots, PackSlot.single('rarity:rare', 2)]);
    final withRares = PlayPool.resolve(rares, sets: const {}, cubes: {'c': deck});
    expect(withRares.packSize, 7);
    expect(withRares.newSource().nextPack().where((c) => c.rarity == Rarity.rare).length,
        greaterThanOrEqualTo(2));

    // A split slot draws each option by its weight.
    final split = base.withTag('x', [for (var i = 0; i < 30; i++) '$i']).copyWith(
      slots: const [PackSlot(1, [SlotOption('x', 1), SlotOption('rarity:rare', 3)])],
      config: const PoolConfig.open(),
    );
    final back = Pool.fromJson(jsonDecode(jsonEncode(split)) as Map<String, dynamic>);
    expect(back.slots.single.options, [const SlotOption('x', 1), const SlotOption('rarity:rare', 3)]);
    expect(PackSlot.fromJson({'tag': 'old', 'count': 2}).options, [const SlotOption('old')]);
    final source = PlayPool.resolve(back, sets: const {}, cubes: {'c': deck}).newSource();
    var fromX = 0;
    for (var i = 0; i < 2000; i++) {
      if (!source.nextPack().single.id.startsWith('r')) fromX++;
    }
    expect(fromX, inInclusiveRange(400, 600), reason: 'one in four, over 2000 draws');
  });

  test('boosters and formats: several kinds of pack, played in order', () {
    final deck = cube([...cards(60), ...cards(10, prefix: 'r', rarity: Rarity.rare)]);
    final pool = Pool.ofCube(deck)
        .withTag('fixing', ['r0', 'r1', 'r2', 'r3'])
        .withBooster(BoosterDef('Fixing', [PackSlot.single('fixing', 2)]));
    expect(pool.boosters.map((b) => b.name), ['Booster', 'Fixing']);
    expect(pool.playFormats.map((f) => f.kind), [FormatKind.sealed, FormatKind.draft],
        reason: 'the game defaults until a format is saved');

    final format = PlayFormat(
      id: 'mixed',
      name: 'Mixed',
      kind: FormatKind.sealed,
      rounds: const [FormatRound('Booster'), FormatRound('Fixing'), FormatRound('Fixing')],
    );
    final saved = pool.withFormat(format);
    expect(saved.formats.map((f) => f.id), ['sealed', 'draft', 'mixed'], reason: 'defaults become yours');
    final back = Pool.fromJson(jsonDecode(jsonEncode(saved)) as Map<String, dynamic>);
    expect(back.boosters[1].slots.single, PackSlot.single('fixing', 2));
    expect(back.formats.last.packsPerPlayer, {'Booster': 1, 'Fixing': 2});

    final play = PlayPool.resolve(back, sets: const {}, cubes: {'c': deck});
    expect(play.boosterPlay('Fixing')!.packSize, 2);
    expect(play.boosterPlay('Fixing')!.packCount, 2, reason: 'four fixing cards, two per pack');
    expect(play.canPlay(format), isTrue);
    expect(play.canPlay(format, players: 2), isFalse, reason: 'two players need four fixing packs');
    final draft = format.copyWith(kind: FormatKind.draft, seats: 8);
    expect(play.seatsForFormat(draft), 1);
    expect(play.seatsForFormat(draft.copyWith(rounds: const [FormatRound('Booster')])), 4,
        reason: '70 cards in packs of 15');

    // Dropping a booster moves the rounds on it to the default one.
    final dropped = saved.withoutBooster('Fixing');
    expect(dropped.boosters, hasLength(1));
    expect(dropped.formats.last.rounds.map((r) => r.booster), ['Booster', 'Booster', 'Booster']);

    // Old pools with a plain slot list load as one booster.
    final old = Pool.fromJson({
      ...pool.toJson()..remove('boosters'),
      'slots': [PackSlot.single('all', 15).toJson()],
    });
    expect(old.boosters.single.name, 'Booster');
    expect(old.slots.single, PackSlot.single('all', 15));
  });

  test('adding a source extends the tags the pool already has', () {
    final deck = cube(cards(20));
    final pool = Pool.ofCube(deck);
    final more = pool.withSource(const CardsSource([]), cards: cards(3, prefix: 'n', rarity: Rarity.rare));
    expect(more.tags[allCardsTag]!.cards, hasLength(23));
    expect(more.tags['rarity:rare']!.cards, ['n0', 'n1', 'n2']);

    final set = loadBundled('ygo/CIBR');
    final fromSet = Pool.ofSet(set, name: 'CIBR');
    final grown = fromSet.withSource(const CardsSource([]),
        cards: cards(2, prefix: 'z'), existing: set.cards);
    expect(grown.tags['rarity:common']!.cards, containsAll(['z0', 'z1']));
    expect(grown.tags['common']!.cards, contains('z0'), reason: 'commons join the common sheet tag');
    expect(grown.tags['rare']!.cards, isNot(contains('z0')));
    expect(grown.tags['common']!.weights['z0'], greaterThan(0), reason: 'at the sheet average');
  });

  group('PoolConfig', () {
    test('presets and per-card overrides', () {
      const open = PoolConfig.open();
      expect(open.preset, PoolPreset.open);
      expect(open.copiesOf('x'), isNull);

      final closed = const PoolConfig.closed(2);
      expect(closed.preset, PoolPreset.closed);
      expect(closed.copiesOf('x', listed: 3), 6);

      final custom = open.withCard('x', 1);
      expect(custom.preset, isNull);
      expect(custom.copiesOf('x'), 1);
      expect(custom.copiesOf('y'), isNull);
      expect(custom.withCard('x', null).preset, PoolPreset.open, reason: 'back to default');
    });

    test('survives JSON, unlimited included', () {
      final config = const PoolConfig.closed(3).withCard('a', null).withCard('b', 0);
      final copy = PoolConfig.fromJson(config.toJson());
      expect(copy.copies, 3);
      expect(copy.overrides, {'a': null, 'b': 0});
    });
  });

  test('closed: the scarcest slot limits the packs', () {
    final dealer = PoolDealer(formula, copiesOf: (_) => 1, random: Random(4));
    expect(dealer.packCount, 15); // 150 commons / 10, although rares allow 30
    for (var i = 0; i < 15; i++) {
      final pack = dealer.nextPack();
      expect(pack.where((c) => c.rarity == Rarity.common), hasLength(10));
      expect(pack.where((c) => c.rarity == Rarity.rare), hasLength(1));
    }
    expect(dealer.nextPack, throwsStateError);

    expect(PoolDealer(formula, copiesOf: (_) => 3).packCount, 45);
  });

  test('closed with unlimited cards: only fully limited slots cap the packs', () {
    // Rares limited to 1 copy, commons unlimited: 30 packs.
    final dealer = PoolDealer(formula,
        copiesOf: (c) => c.rarity == Rarity.rare ? 1 : unlimited, random: Random(5));
    expect(dealer.packCount, 30);
    expect(dealer.cardCount, isNull);
    final rareIds = [for (var i = 0; i < 30; i++) dealer.nextPack().last.id];
    expect(rareIds.toSet(), hasLength(30), reason: 'each rare once');
    expect(dealer.nextPack, throwsStateError);

    // One unlimited rare lifts the limit entirely.
    final lifted = PoolDealer(formula, copiesOf: (c) => c.id == 'r0' ? unlimited : 1);
    expect(lifted.packCount, 15);
    final unlimitedRares = PoolDealer(formula,
        copiesOf: (c) => c.id == 'r0' ? unlimited : (c.rarity == Rarity.common ? unlimited : 1));
    expect(unlimitedRares.packCount, isNull);
  });

  test('open with a limited card: never more than its copies', () {
    final dealer = PoolDealer(formula,
        copiesOf: (c) => c.id == 'r0' ? 2 : unlimited, random: Random(6));
    expect(dealer.packCount, isNull);
    var r0 = 0;
    for (var i = 0; i < 500; i++) {
      r0 += dealer.nextPack().where((c) => c.id == 'r0').length;
    }
    expect(r0, lessThanOrEqualTo(2));
    expect(r0, greaterThan(0), reason: '1 in 30 rares over 500 packs');
  });

  test('a card left out (0 copies) never shows up', () {
    final dealer = PoolDealer(formula, copiesOf: (c) => c.id == 'r0' ? 0 : unlimited);
    for (var i = 0; i < 300; i++) {
      expect(dealer.nextPack().any((c) => c.id == 'r0'), isFalse);
    }
  });

  test('a foil slot sharing cards never starves another slot', () {
    final commons = cards(40);
    final rares = cards(5, prefix: 'r', rarity: Rarity.rare);
    final formula = BoosterFormula(
      variants: [
        const BoosterVariant(weight: 1, contents: {'common': 7, 'rare': 1, 'foil': 1}),
      ],
      sheets: {
        'common': sheet(commons),
        'rare': sheet(rares),
        'foil': sheet([...commons, ...rares], foil: true),
      },
    );
    // 45 cards for 9-card packs: 5 packs, and only 5 rares for the rare slot.
    for (var seed = 0; seed < 50; seed++) {
      final dealer = PoolDealer(formula, copiesOf: (_) => 1, random: Random(seed));
      expect(dealer.packCount, 5);
      final dealt = [for (var i = 0; i < 5; i++) ...dealer.nextPack()];
      expect(dealt.map((c) => c.id).toSet(), hasLength(45), reason: 'each card once');
    }
  });

  test('cubes: closed preset follows listed counts, open is unlimited', () {
    final listed = cube([...cards(20), ...cards(10)]); // cards 0-9 listed twice
    final closed = cubePool(listed);
    expect(closed.cardCount, 30);
    expect(closed.packCount, 2);
    expect(closed.seatsFor(1), 2);
    expect(closed.canDeal(3), isFalse);
    final source = closed.newSource();
    final dealt = [...source.nextPack(), ...source.nextPack()];
    expect(dealt.where((c) => c.id == '0'), hasLength(2));

    final open = cubePool(listed, const PoolConfig.open());
    expect(open.packCount, isNull);
    expect(open.seatsFor(3), 8);
    final pack = open.newSource().nextPack();
    expect(pack.map((c) => c.id).toSet(), hasLength(15), reason: 'no repeat within a pack');
  });

  Pool setPool(CardSet set, PoolConfig config, {List<PoolSource>? sources}) => Pool(
        id: 'p',
        game: set.game,
        name: 'Pool',
        sources: sources ?? [SetSource(set.code)],
        layout: BoosterLayout(set.code),
        config: config,
        updatedAt: DateTime(2026),
      );

  test('a set: open preset keeps the formula, closed keeps its slots', () {
    final set = loadBundled('ygo/CIBR');
    final sets = {set.code: set};
    final open = PlayPool.resolve(setPool(set, const PoolConfig.open()), sets: sets, cubes: {});
    expect(open.newSource(), isA<PackGenerator>());
    expect(open.packSize, 9);
    expect(open.packCount, isNull);

    final closed =
        PlayPool.resolve(setPool(set, const PoolConfig.closed(3)), sets: sets, cubes: {});
    expect(closed.packSize, 9);
    // Cards only in the ultra and secret variants fit no slot of the main layout.
    final mainSlots = PoolDealer.mainVariant(set.booster()).contents.keys;
    final inMain = {
      for (final name in mainSlots) ...set.booster().sheets[name]!.cards.map((c) => c.id),
    };
    expect(closed.unplaced, set.cards.where((c) => !inMain.contains(c.id)).length);
    final commons = set.cards.where((c) => c.rarity == Rarity.common).length;
    expect(closed.packCount, lessThanOrEqualTo(commons * 3 ~/ 7));

    final source = closed.newSource();
    final counts = <String, int>{};
    for (var i = 0; i < closed.packCount!; i++) {
      final pack = source.nextPack();
      expect(pack.where((c) => c.rarity == Rarity.common), hasLength(7));
      for (final card in pack) {
        counts[card.id] = (counts[card.id] ?? 0) + 1;
      }
    }
    expect(counts.values.every((n) => n <= 3), isTrue, reason: 'at most 3 copies of a card');
    expect(source.nextPack, throwsStateError);
  });

  test('cards from another source fill the slots of their rarity', () {
    final set = loadBundled('ygo/CIBR');
    final extra = cube([
      ...cards(70, prefix: 'x'), // commons
      CardData(id: 'm', names: const {}, rarity: Rarity.mythic), // no mythic slot
    ]);
    final pool = setPool(set, const PoolConfig.closed(),
        sources: [SetSource(set.code), CubeSource(extra.id)]);
    final play = PlayPool.resolve(pool, sets: {set.code: set}, cubes: {extra.id: extra});
    expect(play.entries, hasLength(set.cards.length + 71));
    final base = PlayPool.resolve(setPool(set, const PoolConfig.closed()),
        sets: {set.code: set}, cubes: {});
    expect(play.unplaced, base.unplaced + 1, reason: 'the mythic fits no slot');

    final commons = set.cards.where((c) => c.rarity == Rarity.common).length;
    expect(play.packCount, greaterThan(commons ~/ 7), reason: '70 more commons');
    final source = play.newSource();
    final dealt = [for (var i = 0; i < play.packCount!; i++) ...source.nextPack()];
    expect(dealt.where((c) => c.id.startsWith('x')), isNotEmpty);
    expect(dealt.any((c) => c.id == 'm'), isFalse);
  });

  test('pools survive JSON and fall back when their layout set is removed', () {
    final pool = Pool(
      id: 'p',
      game: Game.ygo,
      name: 'Mix',
      sources: const [SetSource('CIBR'), SetSource('LOB'), CubeSource('c')],
      layout: const BoosterLayout('CIBR', booster: BoosterType.standard),
      config: const PoolConfig.closed(2).withCard('CIBR-FR001', null),
      updatedAt: DateTime(2026),
    );
    final copy = Pool.fromJson(pool.toJson());
    expect(copy.sources, pool.sources);
    expect(copy.layout, pool.layout);
    expect(copy.config.overrides, {'CIBR-FR001': null});
    expect(copy.setCodes, ['CIBR', 'LOB']);

    final withoutCibr = pool.withoutSource(const SetSource('CIBR'));
    expect(withoutCibr.layout, const BoosterLayout('LOB'));
    final cubeOnly = withoutCibr.withoutSource(const SetSource('LOB'));
    expect(cubeOnly.layout, const RandomLayout());
    expect(cubeOnly.withSource(const CubeSource('c')).sources, hasLength(1));
  });
}
