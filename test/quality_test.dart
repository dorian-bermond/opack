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
}
