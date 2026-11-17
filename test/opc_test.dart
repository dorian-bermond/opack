import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/data/card_info_repository.dart';
import 'package:opack/features/card_info/data/card_search.dart';
import 'package:opack/features/card_info/domain/card_filter.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_info/domain/pool_metrics.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/presentation/pool_view.dart';
import 'package:opack/shared/images/card_image_cache.dart';

import '../tool/src/opc.dart';

const _perona = {
  'card_name': 'Perona',
  'set_name': 'Romance Dawn',
  'card_text': '[On Play] Look at 5 cards from the top of your deck.',
  'set_id': 'OP-01',
  'rarity': 'UC',
  'card_set_id': 'OP01-077',
  'card_color': 'Blue',
  'card_type': 'Character',
  'life': null,
  'card_cost': '1',
  'card_power': '2000',
  'sub_types': 'Thriller Bark Pirates',
  'counter_amount': 1000,
  'attribute': 'Special',
  'card_image': 'https://optcgapi.com/media/static/Card_Images/OP01-077.jpg',
};

const _chopper = {
  'card_name': 'Tony Tony.Chopper',
  'set_name': 'Romance Dawn',
  'set_id': 'OP-01',
  'rarity': 'UC',
  'card_set_id': 'OP01-015',
  'card_color': 'Red',
  'card_type': 'Character',
  'card_cost': '3',
  'card_power': '4000',
  'sub_types': 'Animal Straw Hat Crew',
  'counter_amount': 1000,
  'attribute': 'Wisdom',
};

const _luffy = {
  'card_name': 'Monkey.D.Luffy',
  'set_name': 'Romance Dawn',
  'set_id': 'OP-01',
  'rarity': 'L',
  'card_set_id': 'OP01-003',
  'card_color': 'Red/Green',
  'card_type': 'Leader',
  'life': 5,
  'card_cost': null,
  'card_power': '5000',
  'sub_types': 'Supernovas Straw Hat Crew',
  'counter_amount': null,
  'attribute': 'Strike',
};

void main() {
  test('an optcgapi card becomes a One Piece card info, and survives saving', () {
    final info = OpcCardInfo.fromOptcg(_chopper);
    expect(info.name, 'Tony Tony.Chopper');
    expect(info.type, 'Character');
    expect(info.colors, ['Red']);
    expect(info.cost, 3);
    expect(info.power, 4000);
    expect(info.counter, 1000);
    expect(info.subtypes, ['Straw Hat Crew', 'Animal'], reason: 'multi-word types kept whole');
    expect(info.attribute, 'Wisdom');
    expect(info.setCode, 'OP01');
    final leader = OpcCardInfo.fromOptcg(_luffy);
    expect(leader.colors, ['Red', 'Green']);
    expect(leader.life, 5);
    expect(leader.cost, isNull);
    final reloaded = CardInfo.fromJson(jsonDecode(jsonEncode(leader.toJson())) as Map<String, dynamic>);
    expect(reloaded, isA<OpcCardInfo>());
    expect((reloaded as OpcCardInfo).subtypes, ['Straw Hat Crew', 'Supernovas']);
    expect(reloaded.life, 5);
  });

  test('rarities, set codes and the booster formula of an imported set', () {
    expect(opcRarity('C'), 'common');
    expect(opcRarity('SR'), 'superRare');
    expect(opcRarity('L'), 'leader');
    expect(opcRarity('SEC'), 'secretRare');
    expect(opcRarity('SP CARD'), 'special');
    expect(opcSetCode('OP-01'), 'OP01');
    expect(opcIsBooster('OP-01'), isTrue);
    expect(opcIsBooster('EB-02'), isTrue);
    expect(opcIsBooster('ST-01'), isFalse);
    expect(CardInfoFetcher.opcSetOf('OP01-077'), 'OP-01');
    expect(CardInfoFetcher.opcSetOf('PRB01-010'), 'PRB-01');
    expect(CardInfoFetcher.opcSetOf('DMU-1'), isNull);

    final set = buildOpcSet('OP-01', 'Romance Dawn', [_perona, _chopper, _luffy, _perona]);
    expect(set['code'], 'OP01');
    expect((set['cards'] as List).length, 3, reason: 'a repeated printing counts once');
    expect(((set['cards'] as List).first as Map)['id'], 'OP01-003', reason: 'sorted by code');
    final booster = (set['boosters'] as Map)['standard'] as Map;
    expect(booster['approximate'], isTrue);
    final variants = (booster['variants'] as List).cast<Map>();
    expect(variants.map((v) => (v['contents'] as Map).keys.last), ['leader'],
        reason: 'only the top slots whose rarity exists');
    expect((variants.single['contents'] as Map)['uncommon'], 2);
    expect(((booster['sheets'] as Map)['leader'] as Map)['cards'], [[0, 1]]);
    final parsed = CardSet.fromJson(jsonDecode(jsonEncode(set)) as Map<String, dynamic>);
    expect(parsed.game, Game.opc);
    expect(parsed.cards.first.rarity, Rarity.leader);
  });

  test('One Piece cards take their picture from optcgapi, by code', () {
    const card = CardData(id: 'OP01-077', names: {'en': 'Perona'}, rarity: Rarity.uncommon);
    expect(isOnePieceId('OP01-077'), isTrue);
    expect(isOnePieceId('EB01-001'), isTrue);
    expect(isOnePieceId('CIBR-FR077'), isFalse);
    expect(isOnePieceId('DMU-1'), isFalse);
    final source = cardImageSource(card, language: 'fr')!;
    expect(source.key, 'opc-OP01-077');
    expect(source.url.toString(), 'https://optcgapi.com/media/static/Card_Images/OP01-077.jpg');
    expect(source.fallback, isNull);
  });

  test('filters, sorts, groupings and metrics know One Piece cards', () {
    final chopper = (card: const CardData(id: 'OP01-015', names: {'en': 'Chopper'}, rarity: Rarity.uncommon),
        info: OpcCardInfo.fromOptcg(_chopper), tags: <String>{});
    final luffy = (card: const CardData(id: 'OP01-003', names: {'en': 'Luffy'}, rarity: Rarity.leader),
        info: OpcCardInfo.fromOptcg(_luffy), tags: <String>{});
    final perona = (card: const CardData(id: 'OP01-077', names: {'en': 'Perona'}, rarity: Rarity.uncommon),
        info: OpcCardInfo.fromOptcg(_perona), tags: <String>{});

    expect(Facet.forGame(Game.opc), contains(Facet.cost));
    expect(Facet.color.valuesOf(luffy), ['Red', 'Green']);
    expect(Facet.type.valuesOf(luffy), ['Leader']);
    expect(Facet.subtype.valuesOf(chopper), contains('Straw Hat Crew'));
    expect(Facet.attribute.valuesOf(perona), ['Special']);
    expect(Facet.cost.numberOf(chopper), 3);
    expect(Facet.power.numberOf(luffy), 5000);
    expect(Facet.counter.numberOf(perona), 1000);
    expect(Facet.set.valuesOf(perona), ['OP01']);
    expect(const CardFilter(chosen: {Facet.color: {'Green'}}).matches(luffy), isTrue);
    expect(const CardFilter(chosen: {Facet.color: {'Green'}}).matches(perona), isFalse);

    expect(CardSort.forGame(Game.opc), contains(CardSort.counter));
    final byCost = [chopper, luffy, perona]..sort((a, b) => CardSort.cost.compare(a, b, 'en'));
    expect(byCost.map((c) => c.card.id), ['OP01-077', 'OP01-015', 'OP01-003'], reason: 'no cost last');
    final byPower = [chopper, luffy, perona]..sort((a, b) => CardSort.power.compare(a, b, 'en'));
    expect(byPower.first.card.id, 'OP01-003');
    final byColor = [perona, luffy, chopper]..sort((a, b) => CardSort.color.compare(a, b, 'en'));
    expect(byColor.map((c) => c.card.id), ['OP01-015', 'OP01-077', 'OP01-003'], reason: 'red, blue, multi');

    expect(GroupBy.forGame(Game.opc), contains(GroupBy.cost));
    expect(stackLabel(CardSort.cost, chopper, 'en'), '3');
    expect(stackLabel(CardSort.color, luffy, 'en'), 'multi');
    expect(stackLabel(CardSort.type, perona, 'en'), 'Character');
    expect(stackLabel(CardSort.counter, luffy, 'en'), '?');

    final metrics = poolMetrics(Game.opc, [chopper, luffy, perona]);
    final curve = metrics.firstWhere((m) => m.metric == Metric.costCurve);
    expect(curve.rows, [('1', 1), ('3', 1)], reason: 'leaders have no cost');
    expect(curve.known, 2);
    final colors = metrics.firstWhere((m) => m.metric == Metric.colors);
    expect(colors.rows, [('Red', 2), ('Green', 1), ('Blue', 1)]);
    final life = metrics.firstWhere((m) => m.metric == Metric.life);
    expect(life.rows, [('5', 1)]);
    expect(metrics.firstWhere((m) => m.metric == Metric.types).rows.first, ('Leader', 1));
  });

  test('a search answer becomes a pool card with its rarity', () {
    final found = CardSearch.opcFound(_luffy)!;
    expect(found.card.id, 'OP01-003');
    expect(found.card.rarity, Rarity.leader);
    expect(found.card.names['en'], 'Monkey.D.Luffy');
    expect(CardSearch.opcRarity('SEC'), Rarity.secretRare);
    expect(CardSearch.opcFound(const {'card_name': 'x'}), isNull);
  });

  test('the leader rarity sits between super rare and ultra rare', () {
    expect(Rarity.leader.index, greaterThan(Rarity.superRare.index));
    expect(Rarity.leader.index, lessThan(Rarity.ultraRare.index));
    expect(Game.opc.sealedPackCount, 6);
  });
}
