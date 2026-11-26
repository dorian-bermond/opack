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

  test("a Yu-Gi-Oh! card's subtypes join its type and categories, and make its type line", () {
    expect(ygoSubtypes(race: 'Zombie', categories: ['Effect', 'Toon']), ['Zombie', 'Toon', 'Effect'],
        reason: 'the categories in their usual order');
    final zombie = ygoSplitSubtypes(['Zombie', 'Toon', 'Effect']);
    expect(zombie.race, 'Zombie');
    expect(zombie.categories, ['Toon', 'Effect']);
    final dragon = ygoSplitSubtypes(['Tuner', 'Dragon', 'Synchro']);
    expect(dragon.race, 'Dragon');
    expect(dragon.categories, ['Tuner', 'Synchro'], reason: 'abilities before the frame');
    expect(ygoSplitSubtypes(const []).race, isNull);
    // Printed order: the tribe, the frame, Pendulum, the abilities, Tuner, Effect.
    expect(ygoSubtypes(race: 'Dragon', categories: ['Effect', 'Tuner', 'Pendulum', 'Synchro']),
        ['Dragon', 'Synchro', 'Pendulum', 'Tuner', 'Effect']);
    expect(ygoSubtypes(race: 'Fairy', categories: ['Effect', 'Tuner', 'Flip']), ['Fairy', 'Flip', 'Tuner', 'Effect']);
    // A new tribe takes the place of the old one; a category joins in its place.
    expect(ygoWithSubtype(['Zombie', 'Toon', 'Effect'], 'Dragon'), ['Dragon', 'Toon', 'Effect']);
    expect(ygoWithSubtype(['Zombie', 'Effect'], 'Synchro'), ['Zombie', 'Synchro', 'Effect']);
    expect(ygoWithSubtype(['Effect'], 'My Own Tribe'), ['My Own Tribe', 'Effect']);
    // A spell or a trap has one word, its kind, even one a monster knows as a category.
    expect(ygoSplitSubtypes(['Normal'], monster: false), (race: 'Normal', categories: const <String>[]));
    expect(ygoWithSubtype(['Normal'], 'Quick-Play', monster: false), ['Quick-Play']);
    expect(ygoTypeString(['Pendulum', 'Tuner', 'Effect'], 'Effect Monster'), 'Pendulum Tuner Effect Monster');
    expect(ygoTypeString(const [], 'Spell Card'), 'Spell Card');
    expect(computedTypeLine(Game.ygo, {'subtypes': ['Zombie', 'Toon', 'Effect']}), 'Zombie / Toon / Effect');
    // The tribe is a field of its own, ahead of the subtypes.
    expect(computedTypeLine(Game.ygo, {'race': 'Dragon', 'subtypes': ['Synchro', 'Effect']}),
        'Dragon / Synchro / Effect');
    expect(computedTypeLine(Game.ygo, {'race': 'Dragon', 'categories': ['Effect', 'Tuner']}), 'Dragon / Tuner / Effect');
    expect(computedTypeLine(Game.ygo, {'race': 'Quick-Play'}), 'Quick-Play', reason: "a spell's kind alone");
    expect(computedTypeLine(Game.ygo, {'race': 'Zombie', 'categories': ['Effect']}), 'Zombie / Effect');
    expect(computedTypeLine(Game.mtg, {'supertypes': ['Legendary'], 'types': ['Artifact'], 'subtypes': ['Equipment']}),
        'Legendary Artifact — Equipment');
    expect(computedTypeLine(Game.mtg, {'types': ['Instant'], 'subtypes': <String>[]}), 'Instant');
    expect(computedTypeLine(Game.opc, {'type': 'Character', 'subtypes': ['Straw Hat Crew']}), 'Character / Straw Hat Crew');
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

  test('an ATK or DEF may be any text; what is no number is worth 0, -1 reads ?', () {
    expect(YgoCardInfo.readStat(2500), (2500, null));
    expect(YgoCardInfo.readStat('2500'), (2500, null), reason: 'a number typed is a number');
    expect(YgoCardInfo.readStat(-1), (0, '?'));
    expect(YgoCardInfo.readStat('-1'), (0, '?'));
    expect(YgoCardInfo.readStat('?'), (0, '?'));
    expect(YgoCardInfo.readStat(' X000 '), (0, 'X000'));
    expect(YgoCardInfo.readStat(''), (null, null));
    expect(YgoCardInfo.readStat(null), (null, null));

    final unknown = YgoCardInfo.fromYgoprodeck(const {
      'id': 1, 'name': 'Kasha', 'type': 'Effect Monster', 'frameType': 'effect', 'race': 'Zombie', 'atk': -1,
      'def': 1000,
    });
    expect(unknown.atk, 0);
    expect(unknown.atkLabel, '?');
    expect(unknown.defLabel, '1000');
    expect(editableInfoFields(unknown)['atk'], '?', reason: 'what the editor shows');
    // Saved and read back as it reads.
    final back = CardInfo.fromJson(unknown.toJson()) as YgoCardInfo;
    expect((back.atk, back.atkLabel, back.def, back.defText), (0, '?', 1000, null));

    // Edited to any text, or back to a number.
    final typed = customizeInfo(unknown, {'atk': 'X000', 'def': '∞'})! as YgoCardInfo;
    expect((typed.atk, typed.atkLabel, typed.def, typed.defLabel), (0, 'X000', 0, '∞'));
    expect(parseFieldText('X000', 2500), 'X000', reason: 'kept as typed where a number was');
    final number = customizeInfo(unknown, {'atk': parseFieldText('3000', '?')})! as YgoCardInfo;
    expect((number.atk, number.atkLabel), (3000, '3000'));
  });
}
