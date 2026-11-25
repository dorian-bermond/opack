import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/domain/card_customs.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';

void main() {
  const card = CardData(id: 'X-1', names: {'en': 'Alpha', 'fr': 'Alpha'}, rarity: Rarity.rare, passcode: '1');
  const info = YgoCardInfo(
      name: 'Alpha', kind: YgoKind.monster, type: 'Effect Monster', frameType: 'effect', race: 'Dragon', atk: 2500, level: 7);

  test('custom fields change a card and its details, the originals kept aside', () {
    final customs = <String, Object?>{
      'card.name.fr': 'Alpha (FR)',
      'card.rarity': 'mythic',
      'card.printedRarity': 'rare',
      'atk': 3000,
      'race': 'Zombie',
      'level': null,
    };
    final custom = customizeCard(card.asFoil(), customs);
    expect(custom.names, {'en': 'Alpha', 'fr': 'Alpha (FR)'});
    expect(custom.rarity, Rarity.mythic);
    expect(custom.printedRarity, Rarity.rare);
    expect(custom.foil, isTrue, reason: 'foil kept');
    expect(custom.id, card.id);
    expect(custom.customFields, customs.keys.toSet(), reason: 'the card knows which fields are its own');
    expect(custom.asFoil().customFields, isNotEmpty);
    expect(customizeCard(card, const {}), same(card));

    final details = customizeInfo(info, customs)! as YgoCardInfo;
    expect(details.atk, 3000);
    expect(details.race, 'Zombie');
    expect(details.level, isNull, reason: 'a field set to nothing');
    expect(details.name, 'Alpha', reason: 'untouched fields stay');
    expect(customizeInfo(null, customs), isNull);
    expect(customizeInfo(info, const {'card.rarity': 'mythic'}), same(info), reason: 'card fields do not touch the details');

    expect(cardFieldKeys(card).first, 'card.name.en');
    expect(cardFieldValue(card, 'card.rarity'), 'rare');
    expect(editableInfoFields(info).keys, isNot(contains('game')));
    expect(editableInfoFields(info)['atk'], 2500);
  });

  test("a Yu-Gi-Oh! frame follows the monster's categories", () {
    expect(ygoFrameFromCategories(['Effect']), 'effect');
    expect(ygoFrameFromCategories(['Pendulum', 'Tuner', 'Effect']), 'effect_pendulum');
    expect(ygoFrameFromCategories(['Fusion', 'Effect', 'Pendulum']), 'fusion_pendulum', reason: 'the extra-deck kind wins');
    expect(ygoFrameFromCategories(['Link', 'Pendulum']), 'link', reason: 'no pendulum link');
    expect(ygoFrameFromCategories(['Normal']), 'normal');
    expect(ygoFrameFromCategories(['Tuner']), isNull, reason: 'no frame word');
    expect(ygoFrameFromCategories(const []), isNull);
  });

  test('field texts parse back as their original kind', () {
    expect(fieldText(['a', 'b']), 'a, b');
    expect(fieldText(null), '');
    expect(parseFieldText('3000', 2500), 3000);
    expect(parseFieldText('x', 2500), 'x', reason: 'not a number: kept as typed');
    expect(parseFieldText('a, b ,c', ['z']), ['a', 'b', 'c']);
    expect(parseFieldText('  ', 'old'), isNull);
    expect(parseFieldText('true', false), isTrue);
  });

  test('a pool keeps its customs, applies them when resolved and remembers the originals', () {
    var pool = Pool.empty(Game.ygo, name: 'p').withSource(const CardsSource([card]), cards: [card]);
    pool = pool.withCustom(card.id, 'card.name.en', 'Omega').withCustom(card.id, 'atk', 3000);
    expect(pool.customsOf(card.id), {'card.name.en': 'Omega', 'atk': 3000});
    final reloaded = Pool.fromJson(jsonDecode(jsonEncode(pool.toJson())) as Map<String, dynamic>);
    expect(reloaded.customsOf(card.id), {'card.name.en': 'Omega', 'atk': 3000});
    expect(reloaded.copyWith(name: 'q').customsOf(card.id), isNotEmpty, reason: 'kept by copyWith');

    final play = PlayPool.resolve(reloaded, sets: const {}, cubes: const {});
    expect(play.entries.single.card.nameFor('en'), 'Omega');
    expect(play.bases[card.id]!.nameFor('en'), 'Alpha', reason: 'the original, to revert to');
    expect((play.customizedInfo(card.id, info)! as YgoCardInfo).atk, 3000);

    final reverted = reloaded.withCustom(card.id, 'atk', null, remove: true).withCustom(card.id, 'card.name.en', null, remove: true);
    expect(reverted.customs, isEmpty, reason: 'a card without custom fields leaves the map');
    expect(reverted.toJson().containsKey('customs'), isFalse);
  });
}
