import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/features/card_info/data/card_info_repository.dart';
import 'package:opack/features/card_info/data/card_search.dart';
import 'package:opack/features/card_info/data/dotgg_one_piece.dart';
import 'package:opack/features/card_info/domain/card_filter.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_info/domain/pool_metrics.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/features/pools/presentation/pool_view.dart';
import 'package:opack/shared/images/artwork_search.dart';
import 'package:opack/shared/images/card_image_cache.dart';

import '../tool/src/opc.dart';

/// A onepiece.gg indexed answer: Perona, Chopper, the Luffy leader with an
/// alternate art, a Japanese row and a DON card.
const _names = [
  'id', 'id_normal', 'rarity', 'cardType', 'name', 'Cost', 'Attribute', 'Power', 'Counter', 'Color', 'Type', //
  'Effect', 'CardSets', 'Life', 'set', 'language',
];
const _data = [
  ['OP01-077', 'OP01-077', 'UC', 'CHARACTER', 'Perona', '1', 'Special', '2000', '1000', 'Blue', 'Thriller Bark Pirates', '[On Play] Look at 5 cards.', '-ROMANCE DAWN- [OP01]', null, 'OP01', 'en'],
  ['OP01-015', 'OP01-015', 'UC', 'CHARACTER', 'Tony Tony.Chopper', 3, 'Wisdom', 4000, 1000, 'Red', 'Animal/Straw Hat Crew', '', '-ROMANCE DAWN- [OP01]', null, 'OP01', 'en'],
  ['OP01-003', 'OP01-003', 'L', 'LEADER', 'Monkey.D.Luffy', null, 'Strike', '5000', null, 'Red/Green', 'Supernovas/Straw Hat Crew', 'x', '-ROMANCE DAWN- [OP01]', 4, 'OP01', 'en'],
  ['OP01-003_p1', 'OP01-003', 'L', 'LEADER', 'Monkey.D.Luffy', null, 'Strike', '5000', null, 'Red/Green', 'Supernovas/Straw Hat Crew', 'x', '-ROMANCE DAWN- [OP01]', 4, 'OP01', 'en'],
  ['OP01-003_p2', 'OP01-003', 'L', 'LEADER', 'モンキー・D・ルフィ', null, '打', '5000', null, 'Red/Green', '', 'x', '', 4, 'OP01', 'jp'],
  ['OP18-001', 'OP18-001', 'L', 'LEADER', 'Karoo', null, 'Strike', '5000', null, 'Red/Blue', 'Animal/Alabasta', 'y', 'BOOSTER PACK -THE DOMINANCE OF GOD- [OP-18]', 4, 'OP18', 'en'],
  ['OP17-081_p1', 'OP17-081', 'SP CARD', 'CHARACTER', 'Gerd', 4, 'Strike', 5000, 1000, 'Green', 'Giant', '', 'EXTRA BOOSTER -ONE PIECE HEROINES EDITION vol.2- [EB-05]', null, 'OP17', 'en'],
  ['DON-001', 'DON-001', 'C', 'DON', 'DON!! card', null, null, null, null, null, '', '', '', null, 'OP01', 'en'],
  ['ST01-001', 'ST01-001', 'L', 'LEADER', 'Luffy (ST)', null, 'Strike', '5000', null, 'Red', 'Straw Hat Crew', '', 'STARTER DECK -Straw Hat Crew- [ST-01]', 5, 'ST01', 'en'],
];
final _json = {'names': _names, 'data': _data};

Map<String, Object?> _row(String id) => DotggOnePiece.parse(_json).firstWhere((r) => r['id'] == id);

http.Client _client() => MockClient((request) async {
      expect(request.url.host, 'api.dotgg.gg');
      return http.Response.bytes(utf8.encode(jsonEncode(_json)), 200);
    });

void main() {
  setUp(DotggOnePiece.reset);

  test('a onepiece.gg row becomes a One Piece card info, and survives saving', () {
    final info = OpcCardInfo.fromDotgg(_row('OP01-015'));
    expect(info.name, 'Tony Tony.Chopper');
    expect(info.type, 'Character');
    expect(info.colors, ['Red']);
    expect(info.cost, 3);
    expect(info.power, 4000);
    expect(info.counter, 1000);
    expect(info.subtypes, ['Animal', 'Straw Hat Crew']);
    expect(info.attribute, 'Wisdom');
    expect(info.setCode, 'OP01');
    expect(info.text, isNull, reason: 'an empty effect is none');
    final leader = OpcCardInfo.fromDotgg(_row('OP01-003'));
    expect(leader.colors, ['Red', 'Green']);
    expect(leader.life, 4);
    expect(leader.cost, isNull);
    expect(leader.type, 'Leader');
    final reloaded = CardInfo.fromJson(jsonDecode(jsonEncode(leader.toJson())) as Map<String, dynamic>);
    expect(reloaded, isA<OpcCardInfo>());
    expect((reloaded as OpcCardInfo).subtypes, ['Supernovas', 'Straw Hat Crew']);
    expect(reloaded.life, 4);
    expect(DotggOnePiece.parse(_json).map((r) => r['id']), isNot(contains('OP01-003_p2')), reason: 'English only');
    expect(DotggOnePiece.setName('BOOSTER PACK -THE DOMINANCE OF GOD- [OP-18]'), 'The Dominance of God');
    expect(DotggOnePiece.setName('-ROMANCE DAWN- [OP01]'), 'Romance Dawn');
  });

  test('rarities, booster sets and the formula of an imported set', () {
    expect(opcRarity('C'), 'common');
    expect(opcRarity('SR'), 'superRare');
    expect(opcRarity('L'), 'leader');
    expect(opcRarity('SEC'), 'secretRare');
    expect(opcRarity('SP CARD'), 'special');
    expect(opcSetCode('OP-01'), 'OP01');
    expect(opcIsBooster('OP18'), isTrue);
    expect(opcIsBooster('EB-02'), isTrue);
    expect(opcIsBooster('PRB01'), isTrue);
    expect(opcIsBooster('ST01'), isFalse);
    expect(opcIsBooster('P'), isFalse);

    expect(opcVersion('OP17-001'), '');
    expect(opcVersion('OP17-001_p1'), 'p1');
    expect(opcVersion('OP12-090_r1'), 'r1');
    expect(opcVersionSheet('OP17-001', 'L'), isNull);
    expect(opcVersionSheet('OP17-001_p1', 'L'), 'parallel');
    expect(opcVersionSheet('OP17-034_p2', 'SR'), 'manga');
    expect(opcVersionSheet('OP17-040_p1', 'SP CARD'), 'special');
    expect(opcPulledFrom('EXTRA BOOSTER -ONE PIECE HEROINES EDITION vol.2- [EB-05]', 'OP17'), 'EB05',
        reason: 'a special art reprint is pulled from the extra booster');
    expect(opcPulledFrom('-ROMANCE DAWN- [OP01]', 'OP01'), 'OP01');
    expect(opcPulledFrom('STARTER DECK -Straw Hat Crew- [ST-01]', 'OP01'), 'OP01', reason: 'not a booster: its own set');
    expect(opcPulledFrom('', 'EB05'), 'EB05');
    expect(opcVersionSheet('OP17-119_p1', 'TR'), 'treasure');
    expect(opcVersionSheet('OP12-090_r1', 'C'), isNull, reason: 'a reprint, never in a booster');

    final bySet = opcCardsBySet(_json);
    expect(bySet.keys, unorderedEquals(['OP01', 'OP18', 'EB05']), reason: 'booster sets only');
    expect(bySet['EB05']!.map((c) => c.id), ['OP17-081_p1'], reason: "Gerd's special art is pulled from EB-05");
    expect(bySet['OP01']!.map((c) => c.id), ['OP01-077', 'OP01-015', 'OP01-003', 'OP01-003_p1'],
        reason: 'every English print but DON cards');

    final set = buildOpcSet('OP01', 'Romance Dawn', [...bySet['OP01']!, ...bySet['OP01']!]);
    expect(set['code'], 'OP01');
    expect((set['cards'] as List).length, 4, reason: 'a repeated card counts once, a version is its own');
    expect(((set['cards'] as List).first as Map)['id'], 'OP01-003', reason: 'sorted by code');
    final booster = (set['boosters'] as Map)['standard'] as Map;
    expect(booster['approximate'], isTrue);
    final variants = (booster['variants'] as List).cast<Map>();
    expect(variants.map((v) => (v['contents'] as Map).keys.last), ['leader', 'parallel'],
        reason: 'only the top slots whose sheet exists');
    expect(variants.map((v) => v['weight']), [150, 38]);
    expect((variants.first['contents'] as Map)['uncommon'], 2);
    final sheets = booster['sheets'] as Map;
    expect((sheets['leader'] as Map)['cards'], [[0, 1]], reason: 'the base leader');
    expect((sheets['parallel'] as Map)['cards'], [[1, 1]], reason: 'its parallel art, apart');
    expect(sheets.containsKey('rare'), isFalse);
    final parsed = CardSet.fromJson(jsonDecode(jsonEncode(set)) as Map<String, dynamic>);
    expect(parsed.game, Game.opc);
    expect(parsed.cards.first.rarity, Rarity.leader);
  });

  test('One Piece pictures come from onepiece.gg by print id, alternate arts too', () {
    const card = CardData(id: 'OP01-077', names: {'en': 'Perona'}, rarity: Rarity.uncommon);
    expect(isOnePieceId('OP01-077'), isTrue);
    expect(isOnePieceId('OP01-003_p1'), isTrue);
    expect(isOnePieceId('CIBR-FR077'), isFalse);
    // The official card list first, in the picture language's edition,
    // then English, then onepiece.gg.
    final french = cardImageSource(card, language: 'fr')!;
    expect(french.key, 'opc-OP01-077-fr');
    expect(french.url.toString(), 'https://fr.onepiece-cardgame.com/images/cardlist/card/OP01-077.png');
    expect(french.extension, 'png');
    final english = french.fallback!;
    expect(english.url.toString(), 'https://en.onepiece-cardgame.com/images/cardlist/card/OP01-077.png');
    final gg = english.fallback!;
    expect(gg.key, 'opc-OP01-077');
    expect(gg.url.toString(), 'https://static.dotgg.gg/onepiece/card/OP01-077.webp');
    expect(gg.extension, 'webp');
    expect(gg.fallback, isNull);
    expect(cardImageSource(card, language: 'en')!.key, 'opc-OP01-077-en');
    final alt = artworkImageSource(card, 'ST17-004_p1');
    expect(alt.url.toString(), 'https://en.onepiece-cardgame.com/images/cardlist/card/ST17-004_p1.png',
        reason: 'the special art as the official list shows it');
    expect(alt.fallback!.url.path, '/onepiece/card/ST17-004_p1.webp');
  });

  test('details, search and alternate arts all read the one list', () async {
    final fetcher = CardInfoFetcher(client: _client());
    final infos = await fetcher.fetch(Game.opc, const [
      CardData(id: 'OP01-003', names: {}, rarity: Rarity.leader),
      CardData(id: 'OP18-001', names: {}, rarity: Rarity.leader),
      CardData(id: 'OP99-001', names: {}, rarity: Rarity.common),
    ]);
    expect(infos.keys, unorderedEquals(['OP01-003', 'OP18-001']));
    expect((infos['OP18-001'] as OpcCardInfo).colors, ['Red', 'Blue']);

    final search = CardSearch(client: _client());
    final found = await search.search(Game.opc, const SearchQuery(text: 'luffy'));
    expect(found.cards.map((f) => f.card.id), ['OP01-003', 'ST01-001'], reason: 'base prints, no DON, no alt');
    expect(found.cards.first.card.rarity, Rarity.leader);
    final red = await search.search(Game.opc, const SearchQuery(colors: {'Green'}));
    expect(red.cards.map((f) => f.card.id), ['OP01-003']);
    final cheap = await search.search(Game.opc, const SearchQuery(manaValue: (0, 2)));
    expect(cheap.cards.map((f) => f.card.id), ['OP01-077']);
    final set18 = await search.search(Game.opc, const SearchQuery(setCode: 'op18'));
    expect(set18.cards.map((f) => f.card.id), ['OP18-001']);

    final arts = await ArtworkSearch(client: _client()).alternatives(
        const CardData(id: 'OP01-003', names: {'en': 'Luffy'}, rarity: Rarity.leader));
    expect(arts.map((a) => a.key), ['OP01-003', 'OP01-003_p1'], reason: 'own first, English prints only');
    expect(arts.first.own, isTrue);
    expect(arts.last.label, 'Alt 1');
  });

  test('filters, sorts, groupings and metrics know One Piece cards', () {
    final chopper = (card: const CardData(id: 'OP01-015', names: {'en': 'Chopper'}, rarity: Rarity.uncommon),
        info: OpcCardInfo.fromDotgg(_row('OP01-015')), tags: <String>{});
    final luffy = (card: const CardData(id: 'OP01-003', names: {'en': 'Luffy'}, rarity: Rarity.leader),
        info: OpcCardInfo.fromDotgg(_row('OP01-003')), tags: <String>{});
    final perona = (card: const CardData(id: 'OP01-077', names: {'en': 'Perona'}, rarity: Rarity.uncommon),
        info: OpcCardInfo.fromDotgg(_row('OP01-077')), tags: <String>{});

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
    expect(life.rows, [('4', 1)]);
    expect(metrics.firstWhere((m) => m.metric == Metric.types).rows.first, ('Leader', 1));
  });

  test('a One Piece booster shows the official product page picture, the leader failing that', () {
    final set = CardSet.fromJson(jsonDecode(jsonEncode(buildOpcSet('OP18', 'The Dominance of God', [
      (id: 'OP18-001', name: 'Karoo', rarityCode: 'L'),
      (id: 'OP18-002', name: 'Vivi', rarityCode: 'C'),
    ]))) as Map<String, dynamic>);
    final french = boosterImageSource(set, language: 'fr')!;
    expect(french.key, 'booster-opc-OP18-fr');
    expect(french.url.toString(), 'https://fr.onepiece-cardgame.com/products/op18.html');
    expect(french.extension, 'webp');
    expect(french.fallback!.key, 'booster-opc-OP18-en');
    expect(french.fallback!.fallback!.url.path, '/onepiece/card/OP18-001.webp', reason: 'the leader');
    expect(boosterImageSource(set, language: 'en')!.key, 'booster-opc-OP18-en');

    const page = '<img src="/renewal/images/common/logo.png"><img src="/onepiececg/bccard/fr/products/2026/09/18/u9x6/img_item01.webp">';
    expect(french.pick!({'html': page}), 'https://fr.onepiece-cardgame.com/onepiececg/bccard/fr/products/2026/09/18/u9x6/img_item01.webp');
    expect(french.pick!({'html': '<p>nothing</p>'}), isNull);
    expect(pickOnePieceProduct({'html': '<img src="https://cdn/x/img_item02.png">'}, site: 'en'), 'https://cdn/x/img_item02.png');
  });

  test("a set's top slot becomes one slot with weighted options in the pool", () {
    final set = CardSet.fromJson(jsonDecode(jsonEncode(buildOpcSet('OP18', 'The Dominance of God', [
      (id: 'OP18-001', name: 'Karoo', rarityCode: 'L'),
      (id: 'OP18-001_p1', name: 'Karoo', rarityCode: 'L'),
      (id: 'OP18-002', name: 'Vivi', rarityCode: 'C'),
      (id: 'OP18-003', name: 'Pell', rarityCode: 'UC'),
      (id: 'OP18-004', name: 'Chaka', rarityCode: 'R'),
      (id: 'OP18-005', name: 'Crocodile', rarityCode: 'SR'),
      (id: 'OP18-005_p2', name: 'Crocodile', rarityCode: 'SR'),
      (id: 'OP18-119', name: 'Imu', rarityCode: 'SEC'),
    ]))) as Map<String, dynamic>);
    final (:tags, :slots) = prefillFromSet(set);
    expect(slots.map((s) => '${s.count}×${s.options.map((o) => '${o.tag}:${o.weight}').join('|')}'), [
      '7×common:1',
      '2×uncommon:1',
      '2×rare:1',
      '1×rare:250|superRare:175|leader:150|secretRare:18|parallel:38|manga:2',
    ]);
    expect(slots.fold(0, (n, s) => n + s.count), 12);
    expect(tags['parallel']!.cards, ['OP18-001_p1']);
    expect(tags['manga']!.cards, ['OP18-005_p2']);
    expect(tags['leader']!.cards, ['OP18-001']);

    // Without uncommons (an extra booster), commons and rares fill the pack.
    final extra = CardSet.fromJson(jsonDecode(jsonEncode(buildOpcSet('EB05', 'Heroines', [
      (id: 'EB05-001', name: 'Nami', rarityCode: 'C'),
      (id: 'EB05-002', name: 'Robin', rarityCode: 'R'),
      (id: 'EB05-003', name: 'Hancock', rarityCode: 'SR'),
    ]))) as Map<String, dynamic>);
    final (slots: extraSlots, tags: _) = prefillFromSet(extra);
    expect(extraSlots.map((s) => s.count), [8, 3, 1]);
  });

  test('the leader rarity sits between super rare and ultra rare', () {
    expect(Rarity.leader.index, greaterThan(Rarity.superRare.index));
    expect(Rarity.leader.index, lessThan(Rarity.ultraRare.index));
    expect(Game.opc.sealedPackCount, 6);
  });
}
