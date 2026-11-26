import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/features/pools/domain/pool_transfer.dart';

void main() {
  const card = CardData(id: 'X-1', names: {'en': 'Alpha'}, rarity: Rarity.rare);

  test('a pool goes to a file and back, its device-bound picture left out', () {
    var pool = Pool.empty(Game.ygo, name: 'Sam: zombies?').withSource(const CardsSource([card]), cards: [card]);
    pool = pool.withArtwork('X-1', 'scan').withCover('C:/covers/x.png', printed: true).withBestVersions(true);
    expect(poolFileName(pool), 'Sam  zombies.opack.json');

    final back = decodePool(encodePool(pool));
    expect(back.id, pool.id);
    expect(back.name, pool.name);
    expect(back.game, Game.ygo);
    expect(back.sources, pool.sources);
    expect(back.tags.keys, pool.tags.keys);
    expect(back.artworks, {'X-1': 'scan'});
    expect(back.bestVersions, isTrue);
    expect(back.cover, isNull, reason: 'a path on this device means nothing elsewhere');
    expect(back.coverPrinted, isFalse);
  });

  test('anything else is refused', () {
    expect(() => decodePool('{"format":"other","pool":{}}'.codeUnits), throwsFormatException);
    expect(() => decodePool('not json'.codeUnits), throwsFormatException);
    expect(() => decodePool('{"format":"opack-pool","version":1,"pool":{"id":"p"}}'.codeUnits), throwsFormatException,
        reason: 'a pool missing its fields');
  });

  test('a pool exports as a card list: copies and names, sorted, cards left out skipped', () {
    const zebra = CardData(id: 'X-2', names: {'en': 'Zebra', 'fr': 'Zèbre'}, rarity: Rarity.common);
    const beta = CardData(id: 'X-3', names: {'en': 'beta'}, rarity: Rarity.common);
    const gone = CardData(id: 'X-4', names: {'en': 'Gone'}, rarity: Rarity.common);
    final cards = [zebra, card, beta, gone];
    var pool = Pool.empty(Game.ygo, name: 'Sam: zombies?').withSource(CardsSource(cards), cards: cards);
    pool = pool.copyWith(
      config: pool.config.withCard('X-1', 3).withCard('X-3', null).withCard('X-4', 0),
    );
    final play = PlayPool.resolve(pool, sets: const {}, cubes: const {});
    final byDefault = pool.copiesOf('X-2', listed: 1) ?? 1;

    expect(poolCardListFileName(pool), 'Sam  zombies.txt');
    expect(poolCardList(play, 'en').split('\n'), ['3 Alpha', '1 beta', '$byDefault Zebra', ''],
        reason: 'unlimited copies count once, no copy is not listed, case does not order');
    expect(poolCardList(play, 'fr').split('\n'), ['3 Alpha', '1 beta', '$byDefault Zèbre', ''],
        reason: 'English where no French name');
  });
}
