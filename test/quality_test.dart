import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/domain/pool.dart';

void main() {
  test('a quality groups exclusive tags: gaining one drops the others', () {
    expect(Pool.qualityOf('rarity:rare'), 'rarity');
    expect(Pool.qualityOf('mine'), isNull);
    expect(Pool.qualityTag('theme', 'dragons'), 'theme:dragons');

    var pool = Pool.empty(Game.mtg, name: 'p')
        .withTag('rarity:common', ['a', 'b'])
        .withTag('rarity:rare', ['c'])
        .withTag('mine', ['a']);
    expect(pool.qualities, ['rarity']);
    expect(pool.siblingsOf('rarity:rare').toList(), ['rarity:common']);
    expect(pool.siblingsOf('mine'), isEmpty);

    // Card a becomes rare: it leaves the commons, keeps its plain tag.
    pool = pool.withTag('rarity:rare', ['c', 'a']);
    expect(pool.tags['rarity:rare']!.cards, ['c', 'a']);
    expect(pool.tags['rarity:common']!.cards, ['b']);
    expect(pool.tags['mine']!.cards, ['a']);

    // Setting a tag to the cards it already has changes nothing else.
    pool = pool.withTag('rarity:rare', ['c', 'a']);
    expect(pool.tags['rarity:common']!.cards, ['b']);

    // A plain tag never evicts.
    pool = pool.withTag('mine', ['a', 'b', 'c']);
    expect(pool.tags['rarity:common']!.cards, ['b']);
    expect(pool.tags['rarity:rare']!.cards, ['c', 'a']);

    // Siblings keep their prefilled weights for the cards that stay.
    pool = pool.copyWith(tags: {
      ...pool.tags,
      'rarity:common': const TagDef(['b', 'd'], weights: {'b': 3, 'd': 5}),
    });
    pool = pool.withTag('rarity:rare', ['c', 'a', 'd']);
    expect(pool.tags['rarity:common']!.cards, ['b']);
    expect(pool.tags['rarity:common']!.weights, {'b': 3});
  });

  test('cards rank within a value, values rank within a quality', () {
    var pool = Pool.empty(Game.mtg, name: 'p')
        .withTag('tier:S', ['a', 'b'])
        .withTag('tier:A', ['c'])
        .withTag('mine', ['a']);

    // Before a card, last, or moved within its own tag.
    pool = pool.withCardInTag('tier:S', 'c', before: 'b');
    expect(pool.tags['tier:S']!.cards, ['a', 'c', 'b']);
    expect(pool.tags['tier:A']!.cards, isEmpty, reason: 'the quality stays exclusive');
    pool = pool.withCardInTag('tier:S', 'a');
    expect(pool.tags['tier:S']!.cards, ['c', 'b', 'a']);
    pool = pool.withCardInTag('tier:S', 'a', before: 'zzz');
    expect(pool.tags['tier:S']!.cards, ['c', 'b', 'a'], reason: 'an unknown anchor means last');
    pool = pool.withCardInTag('tier:A', 'b', before: 'c');
    expect(pool.tags['tier:A']!.cards, ['b']);
    expect(pool.tags['tier:S']!.cards, ['c', 'a']);

    // Values: moved before another, to the end, or left alone.
    expect(pool.tags.keys.toList(), ['tier:S', 'tier:A', 'mine']);
    pool = pool.withTagBefore('tier:A', 'tier:S');
    expect(pool.tags.keys.toList(), ['tier:A', 'tier:S', 'mine']);
    pool = pool.withTagBefore('tier:A', null);
    expect(pool.tags.keys.toList(), ['tier:S', 'mine', 'tier:A']);
    expect(pool.withTagBefore('tier:A', 'tier:A').tags.keys.toList(), ['tier:S', 'mine', 'tier:A']);
    expect(pool.withTagBefore('nope', 'tier:S').tags.keys.toList(), ['tier:S', 'mine', 'tier:A']);
    expect(pool.qualities, ['tier']);
  });

  test('a quality reads lowest or best first, rarity best first by default', () {
    var pool = Pool.empty(Game.mtg, name: 'p')
        .withTag('rarity:common', ['a'])
        .withTag('rarity:rare', ['b'])
        .withTag('tier:S', ['c'])
        .withTag('tier:A', ['d']);
    expect(pool.isDescending('rarity'), isTrue);
    expect(pool.isDescending('tier'), isFalse);
    expect(pool.orderedValuesOf('rarity'), ['rarity:rare', 'rarity:common']);
    expect(pool.orderedValuesOf('tier'), ['tier:S', 'tier:A']);

    pool = pool.withQualityDescending('rarity', false).withQualityDescending('tier', true);
    expect(pool.orderedValuesOf('rarity'), ['rarity:common', 'rarity:rare']);
    expect(pool.orderedValuesOf('tier'), ['tier:A', 'tier:S']);
    final reloaded = Pool.fromJson(pool.toJson());
    expect(reloaded.descending, {'rarity': false, 'tier': true});

    // Reordering values keeps them in place among the other tags.
    pool = pool.withValuesOrder('tier', ['tier:A', 'tier:S']);
    expect(pool.tags.keys.toList(), ['rarity:common', 'rarity:rare', 'tier:A', 'tier:S']);
    expect(pool.withValuesOrder('tier', ['tier:S']).tags.keys.toList(), pool.tags.keys.toList(),
        reason: 'an incomplete order is ignored');
    expect(pool.withValuesOrder('nope', []).tags.keys.toList(), pool.tags.keys.toList());
  });

  test('renaming a tag keeps its place, cards, color and booster slots', () {
    var pool = Pool.empty(Game.mtg, name: 'p')
        .withTag('tier:S', ['a'])
        .withTagColor('tier:S', 1)
        .withTag('tier:A', ['b'])
        .withTag('mine', ['a'])
        .copyWith(slots: [PackSlot(1, const [SlotOption('tier:S', 2), SlotOption('mine')])]);
    pool = pool.withTagRenamed('tier:S', 'tier:SS');
    expect(pool.tags.keys.toList(), ['tier:SS', 'tier:A', 'mine']);
    expect(pool.tags['tier:SS']!.cards, ['a']);
    expect(pool.tags['tier:SS']!.color, 1);
    expect(pool.slots.single.options.map((o) => '${o.tag}:${o.weight}'), ['tier:SS:2', 'mine:1']);
    expect(pool.withTagRenamed('tier:A', 'mine').tags.keys.toList(), pool.tags.keys.toList(), reason: 'taken');
    expect(pool.withTagRenamed('nope', 'x').tags.keys.toList(), pool.tags.keys.toList());
    // Renaming into another quality carries the order preference along.
    pool = pool.withQualityDescending('tier', true).withTagRenamed('tier:SS', 'grade:SS');
    expect(pool.isDescending('grade'), isTrue);
  });

  test('a quality value sets the copies of its cards, under a card\'s own count', () {
    var pool = Pool.empty(Game.mtg, name: 'p')
        .withTag('rarity:common', ['a', 'b'])
        .withTag('rarity:rare', ['c'])
        .withTag('mine', ['a', 'c']);
    expect(pool.copiesOf('a'), 1, reason: 'the closed preset');
    pool = pool.withTagCopies('rarity:common', set: true, copies: 4).withTagCopies('mine', set: true, copies: 7);
    expect(pool.copiesOf('a'), 4, reason: 'the value, not the plain tag');
    expect(pool.copiesOf('a', listed: 2), 8, reason: 'per listing, like the preset');
    expect(pool.copiesOf('b'), 4);
    expect(pool.copiesOf('c'), 1, reason: 'rare sets nothing');
    pool = pool.withTagCopies('rarity:rare', set: true, copies: null);
    expect(pool.copiesOf('c'), isNull, reason: 'unlimited');
    pool = pool.copyWith(config: pool.config.withCard('a', 2));
    expect(pool.copiesOf('a'), 2, reason: 'the card\'s own count wins');
    expect(pool.valueCopiesOf('b'), (set: true, copies: 4));
    expect(pool.valueCopiesOf('zzz'), (set: false, copies: null));

    final reloaded = Pool.fromJson(pool.toJson());
    expect(reloaded.tags['rarity:common']!.copies, 4);
    expect(reloaded.tags['rarity:rare']!.copiesSet, isTrue);
    expect(reloaded.tags['rarity:rare']!.copies, isNull);
    expect(reloaded.tags['mine']!.copies, 7);
    expect(pool.withTagCopies('rarity:common', set: false).tags['rarity:common']!.copiesSet, isFalse);
    expect(pool.withTag('rarity:common', ['a', 'b', 'c']).tags['rarity:common']!.copies, 4, reason: 'kept by withCards');
    expect(pool.withTagRenamed('rarity:common', 'rarity:c').tags['rarity:c']!.copies, 4);
  });

  test('the tierlist opens on the last quality used, while it exists', () {
    var pool = Pool.empty(Game.mtg, name: 'p').withTag('rarity:rare', ['a']).withTag('tier:S', ['b']);
    expect(pool.defaultTierlistQuality, 'rarity', reason: 'the first one');
    pool = pool.copyWith(tierlistQuality: 'tier');
    expect(pool.defaultTierlistQuality, 'tier');
    expect(Pool.fromJson(pool.toJson()).tierlistQuality, 'tier');
    expect(pool.withoutTag('tier:S').defaultTierlistQuality, 'rarity', reason: 'gone: back to the first');
    expect(Pool.empty(Game.mtg, name: 'q').defaultTierlistQuality, isNull);
  });

  test('a value keeps its color through edits and saving', () {
    var pool = Pool.empty(Game.mtg, name: 'p').withTag('tier:S', ['a']).withTagColor('tier:S', 0xFFE53935);
    expect(pool.tags['tier:S']!.color, 0xFFE53935);
    pool = pool.withTag('tier:S', ['a', 'b']);
    expect(pool.tags['tier:S']!.color, 0xFFE53935, reason: 'withCards keeps it');
    pool = pool.copyWith(tags: {'tier:S': pool.tags['tier:S']!.plus(['c'])});
    expect(pool.tags['tier:S']!.color, 0xFFE53935, reason: 'plus keeps it');
    final json = pool.toJson();
    expect(Pool.fromJson(json).tags['tier:S']!.color, 0xFFE53935);
    expect(pool.withTagColor('tier:S', null).tags['tier:S']!.color, isNull);
    expect(pool.withTagColor('new', 0xFF000000).tags['new']!.cards, isEmpty);
    expect(pool.plainTags, isEmpty);
    expect(pool.valuesOf('tier'), ['tier:S']);
  });
}
