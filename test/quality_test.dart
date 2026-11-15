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
}
