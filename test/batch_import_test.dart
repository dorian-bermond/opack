import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/presentation/batch_import.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/domain/pool.dart';

void main() {
  test('a pasted list reads counts and names, skipping blanks and lone numbers', () {
    const text = '''
1

Alghoul Mazera
1 Call of the Forgotten

2x Spirit Shield
Kasha x3
  4 X Book of Life
Pyramid Turtle
''';
    expect(parseCardList(text), [
      (count: 1, name: 'Alghoul Mazera'),
      (count: 1, name: 'Call of the Forgotten'),
      (count: 2, name: 'Spirit Shield'),
      (count: 3, name: 'Kasha'),
      (count: 4, name: 'Book of Life'),
      (count: 1, name: 'Pyramid Turtle'),
    ]);
    expect(parseCardList(''), isEmpty);
    expect(parseCardList('0 Zero'), [(count: 1, name: 'Zero')]);
  });

  test('a list comes in with or without its rarities', () {
    const card = CardData(id: 'X-1', names: {'en': 'X'}, rarity: Rarity.rare);
    final pool = Pool.empty(Game.ygo, name: 'p');
    final withRarities = pool.withSource(const CardsSource([card]), cards: [card]);
    expect(withRarities.tags[rarityTag(Rarity.rare)]!.cards, ['X-1']);
    final without = pool.withSource(const CardsSource([card]), cards: [card], rarities: false);
    expect(without.tags.containsKey(rarityTag(Rarity.rare)), isFalse);
    expect(without.sources.whereType<CardsSource>().single.cards.single.id, 'X-1');
  });
}
