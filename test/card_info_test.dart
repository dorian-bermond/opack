import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/features/card_info/data/card_info_repository.dart';
import 'package:opack/features/card_info/domain/card_filter.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_info/domain/pool_metrics.dart';
import 'package:opack/features/catalog/domain/models.dart';

const _scryfallCreature = {
  'id': 'tetsuo',
  'name': 'Tetsuo, Imperial Champion',
  'layout': 'normal',
  'mana_cost': '{U}{B}{R}',
  'cmc': 3.0,
  'type_line': 'Legendary Creature — Human Samurai',
  'power': '3',
  'toughness': '3',
  'colors': ['B', 'R', 'U'],
  'color_identity': ['B', 'R', 'U'],
  'keywords': ['Trample'],
  'set': 'dmc',
  'collector_number': '66',
};

const _scryfallDfc = {
  'id': 'survivor',
  'name': 'Bereaved Survivor // Dauntless Avenger',
  'layout': 'transform',
  'cmc': 3.0,
  'type_line': 'Creature — Human Peasant // Creature — Human Soldier',
  'color_identity': ['W'],
  'keywords': [],
  'set': 'mid',
  'collector_number': '4',
  'card_faces': [
    {'name': 'Bereaved Survivor', 'mana_cost': '{2}{W}', 'type_line': 'Creature — Human Peasant', 'power': '2', 'toughness': '1', 'colors': ['W']},
    {'name': 'Dauntless Avenger', 'type_line': 'Creature — Human Soldier', 'power': '3', 'toughness': '2', 'colors': ['W']},
  ],
};

const _ygoMonster = {
  'id': 92327802,
  'name': 'Defect Compiler',
  'type': 'Effect Monster',
  'frameType': 'effect',
  'desc': 'Some effect',
  'race': 'Cyberse',
  'attribute': 'LIGHT',
  'atk': 1000,
  'def': 1000,
  'level': 3,
  'archetype': 'Code Talker',
  'card_sets': [
    {'set_name': '2018 Mega-Tin Mega Pack', 'set_code': 'MP18-EN104'},
    {'set_name': 'Circuit Break', 'set_code': 'CIBR-EN001'},
  ],
  'misc_info': [{'has_effect': 1}],
};

const _ygoSpell = {
  'id': 1,
  'name': 'Some Spell',
  'type': 'Spell Card',
  'frameType': 'spell',
  'race': 'Quick-Play',
  'card_sets': [],
};

CardData _card(String id, {Rarity rarity = Rarity.common, String? scryfallId, String? passcode}) =>
    CardData(id: id, names: {'en': id}, rarity: rarity, scryfallId: scryfallId, passcode: passcode);

void main() {
  group('MtgCardInfo', () {
    test('reads a Scryfall card and splits its type line', () {
      final info = MtgCardInfo.fromScryfall(_scryfallCreature);
      expect(info.manaValue, 3);
      expect(info.supertypes, ['Legendary']);
      expect(info.types, ['Creature']);
      expect(info.subtypes, ['Human', 'Samurai']);
      expect(info.pips, {'U': 1, 'B': 1, 'R': 1});
      expect(info.powerValue, 3);
      expect(info.setCode, 'DMC');
      expect(info.typeLine, 'Legendary Creature — Human Samurai');
      final back = MtgCardInfo.fromJson(info.toJson());
      expect(back.keywords, ['Trample']);
      expect(back.faces.single.name, 'Tetsuo, Imperial Champion');
    });

    test('a two-faced card takes cost, colors and size from its front', () {
      final info = MtgCardInfo.fromScryfall(_scryfallDfc);
      expect(info.manaCost, '{2}{W}');
      expect(info.colors, ['W']);
      expect(info.types, ['Creature']);
      expect(info.subtypes, ['Human', 'Peasant']);
      expect(info.power, '2');
      expect(info.faces.map((f) => f.name), ['Bereaved Survivor', 'Dauntless Avenger']);
    });
  });

  group('YgoCardInfo', () {
    test('reads a YGOPRODeck monster and its matching printing', () {
      final info = YgoCardInfo.fromYgoprodeck(_ygoMonster, printCode: 'CIBR-FR001');
      expect(info.kind, YgoKind.monster);
      expect(info.categories, ['Effect']);
      expect(info.setCode, 'CIBR-EN001');
      expect(info.setName, 'Circuit Break');
      expect(info.hasEffect, isTrue);
      final back = YgoCardInfo.fromJson(info.toJson());
      expect(back.atk, 1000);
      expect(back.archetype, 'Code Talker');
    });

    test('a spell has a property instead of a monster type', () {
      final info = YgoCardInfo.fromYgoprodeck(_ygoSpell);
      expect(info.kind, YgoKind.spell);
      expect(info.race, 'Quick-Play');
      expect(info.setName, isNull);
      expect(Facet.property.valuesOf((card: _card('X-1'), info: info, tags: const {})), ['Quick-Play']);
      expect(Facet.race.valuesOf((card: _card('X-1'), info: info, tags: const {})), isEmpty);
    });
  });

  group('filter and sort', () {
    final creature = (card: _card('DMC-66', rarity: Rarity.mythic), info: MtgCardInfo.fromScryfall(_scryfallCreature), tags: const {'mine'});
    final dfc = (card: _card('MID-4', rarity: Rarity.rare), info: MtgCardInfo.fromScryfall(_scryfallDfc), tags: const <String>{});
    final unknown = (card: _card('MID-12', rarity: Rarity.common), info: null, tags: const {'rarity:common'});

    test('facets match any chosen value and number ranges', () {
      const white = CardFilter(chosen: {Facet.color: {'W'}});
      expect(white.matches(creature), isFalse);
      expect(white.matches(dfc), isTrue);
      expect(white.matches(unknown), isFalse, reason: 'no details, no colors');
      final either = white.toggle(Facet.color, 'U');
      expect(either.matches(creature), isTrue);
      expect(either.toggle(Facet.color, 'U').toggle(Facet.color, 'W').isEmpty, isTrue);

      const cheap = CardFilter(ranges: {Facet.manaValue: (0, 2)});
      expect(cheap.matches(creature), isFalse);
      expect(cheap.withRange(Facet.manaValue, (3, 3)).matches(creature), isTrue);
      expect(cheap.withRange(Facet.manaValue, null).isEmpty, isTrue);
      expect(const CardFilter(chosen: {Facet.rarity: {'common'}}).matches(unknown), isTrue);
      expect(const CardFilter(chosen: {Facet.tag: {'mine'}}).matches(creature), isTrue);
      expect(const CardFilter(chosen: {Facet.tag: {'mine'}}).matches(dfc), isFalse);
    });

    test('sorts with unknown values last and ties by rarity then name', () {
      final items = [unknown, dfc, creature];
      expect([for (final i in items..sort((a, b) => CardSort.manaValue.compare(a, b, 'en'))) i.card.id],
          ['DMC-66', 'MID-4', 'MID-12']);
      expect([for (final i in items..sort((a, b) => CardSort.color.compare(a, b, 'en'))) i.card.id],
          ['MID-4', 'DMC-66', 'MID-12'], reason: 'mono white before multicolor');
      expect([for (final i in items..sort((a, b) => CardSort.collector.compare(a, b, 'en'))) i.card.id],
          ['MID-4', 'MID-12', 'DMC-66']);
      expect([for (final i in items..sort((a, b) => CardSort.rarity.compare(a, b, 'en'))) i.card.id],
          ['DMC-66', 'MID-4', 'MID-12']);
    });

    test('by name ignores rarity, quotes, case and accents', () {
      CardWithInfo named(String name, Rarity rarity) => (
            card: CardData(id: name, names: {'en': name}, rarity: rarity),
            info: null,
            tags: const <String>{},
          );
      final items = [
        named('Zombyra the Dark', Rarity.ultraRare),
        named('"A" Cell Incubator', Rarity.common),
        named('Épée', Rarity.rare),
        named('blue-Eyes', Rarity.secretRare),
        named('Dark Magician', Rarity.common),
      ]..sort((a, b) => CardSort.name.compare(a, b, 'en'));
      expect([for (final i in items) i.card.id],
          ['"A" Cell Incubator', 'blue-Eyes', 'Dark Magician', 'Épée', 'Zombyra the Dark']);
    });

    test('metrics count colors, curve, types and creature sizes', () {
      final sections = {for (final s in poolMetrics(Game.mtg, [creature, dfc, unknown])) s.metric: s};
      expect(sections[Metric.manaCurve]!.rows, [('3', 2)]);
      expect(sections[Metric.manaCurve]!.average, 3);
      expect(sections[Metric.colors]!.rows, [('W', 1), ('U', 1), ('B', 1), ('R', 1)]);
      expect(sections[Metric.colorCount]!.rows, [('mono', 1), ('multi', 1)]);
      expect(sections[Metric.types]!.rows, [('Creature', 2)]);
      expect(sections[Metric.creatureSize]!.rows, [('3/3', 1), ('2/1', 1)]);
      expect(sections[Metric.rarity]!.rows, [('mythic', 1), ('rare', 1), ('common', 1)]);
      expect(sections[Metric.sets]!.rows, [('MID', 2), ('DMC', 1)]);
      expect(sections.containsKey(Metric.kind), isFalse);
    });
  });

  group('store and fetcher', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('opack-info'));
    tearDown(() => dir.delete(recursive: true));

    test('saves details per pool', () async {
      final store = CardInfoStore(Future.value(dir));
      final info = MtgCardInfo.fromScryfall(_scryfallCreature);
      await store.save('p1', {'DMC-66': info});
      expect((await store.load('p1'))['DMC-66']?.name, 'Tetsuo, Imperial Champion');
      expect(await store.load('p2'), isEmpty);
      await store.delete('p1');
      expect(await store.load('p1'), isEmpty);
    });

    test('fetches MtG cards in one collection call and maps them back', () async {
      final posted = <String>[];
      final fetcher = CardInfoFetcher(client: MockClient((request) async {
        posted.add(request.body);
        return http.Response.bytes(utf8.encode(jsonEncode({'data': [_scryfallCreature], 'not_found': []})), 200);
      }));
      final infos = await fetcher.fetch(Game.mtg, [
        _card('DMC-66', scryfallId: 'tetsuo'),
        _card('DMC-66★', scryfallId: 'tetsuo'),
        _card('X-1'),
      ]);
      expect(posted, hasLength(1));
      expect(infos.keys, ['DMC-66', 'DMC-66★']);
    });

    test('fetches Yu-Gi-Oh! cards by passcode, one by one after a refusal', () async {
      final queried = <String>[];
      final fetcher = CardInfoFetcher(client: MockClient((request) async {
        final ids = request.url.queryParameters['id']!;
        queried.add(ids);
        if (ids.contains(',')) return http.Response('{"error":"No card matching your query was found"}', 400);
        return ids == '92327802'
            ? http.Response.bytes(utf8.encode(jsonEncode({'data': [_ygoMonster]})), 200)
            : http.Response('{}', 400);
      }));
      final infos = await fetcher.fetch(Game.ygo, [
        _card('CIBR-FR001', passcode: '92327802'),
        _card('XXX-FR001', passcode: '00000001'),
      ], language: 'fr');
      expect(queried, ['92327802,1', '92327802', '1']);
      expect((infos['CIBR-FR001'] as YgoCardInfo).setCode, 'CIBR-EN001');
      expect(infos.containsKey('XXX-FR001'), isFalse);
    });
  });
}
