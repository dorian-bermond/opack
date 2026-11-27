import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/features/card_info/data/card_search.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/catalog/domain/models.dart';

void main() {
  test('builds a Scryfall query from the facets', () {
    const query = SearchQuery(
      text: 'goblin',
      rarities: {Rarity.common, Rarity.uncommon},
      colors: {'R', 'G'},
      types: {'Creature'},
      keywords: {'Haste', 'First strike'},
      setCode: 'dmu',
      manaValue: (1, 3),
    );
    expect(query.scryfall,
        'goblin (r:common or r:uncommon) c:rg t:creature kw:haste kw:first-strike set:dmu mv>=1 mv<=3');
    expect(const SearchQuery().isEmpty, isTrue);
    expect(const SearchQuery(colors: {'C'}).scryfall, 'c:c');
  });

  test('builds YGOPRODeck parameters, keeping low bounds only', () {
    const query = SearchQuery(
      text: 'dragon',
      ygoTypes: {'Effect Monster', 'Spell Card'},
      attributes: {'LIGHT'},
      race: 'Dragon',
      archetype: 'Blue-Eyes',
      level: (4, 8),
      atk: (2500, 3000),
    );
    expect(query.ygoprodeck, {
      'fname': 'dragon',
      'type': 'Effect Monster,Spell Card',
      'attribute': 'LIGHT',
      'race': 'Dragon',
      'archetype': 'Blue-Eyes',
      'level': 'gte4',
      'atk': 'gte2500',
    });
  });

  test('turns Scryfall and YGOPRODeck cards into pool cards with details', () {
    final mtg = CardSearch.mtgFound({
      'id': 'abc',
      'name': 'Llanowar Elves',
      'rarity': 'uncommon',
      'set': 'dmu',
      'collector_number': '168',
      'cmc': 1.0,
      'mana_cost': '{G}',
      'colors': ['G'],
      'type_line': 'Creature — Elf Druid',
      'keywords': [],
    }, frenchNames: {'Llanowar Elves': 'Elfes de Llanowar'});
    expect(mtg.card.id, 'DMU-168');
    expect(mtg.card.names, {'en': 'Llanowar Elves', 'fr': 'Elfes de Llanowar'});
    expect(mtg.card.rarity, Rarity.uncommon);
    expect(mtg.card.colors, 'G');
    expect(mtg.card.scryfallId, 'abc');
    expect((mtg.info as MtgCardInfo).subtypes, ['Elf', 'Druid']);

    final ygo = CardSearch.ygoFound({
      'id': 89631139,
      'name': 'Blue-Eyes White Dragon',
      'type': 'Normal Monster',
      'frameType': 'normal',
      'race': 'Dragon',
      'attribute': 'LIGHT',
      'atk': 3000,
      'def': 2500,
      'level': 8,
      'card_sets': [
        {'set_name': 'Legend of Blue Eyes White Dragon', 'set_code': 'LOB-001', 'set_rarity': 'Ultra Rare'},
      ],
    }, localizedName: 'Dragon Blanc aux Yeux Bleus', language: 'fr');
    expect(ygo.card.id, 'LOB-001');
    expect(ygo.card.rarity, Rarity.ultraRare);
    expect(ygo.card.passcode, '89631139');
    expect(ygo.card.nameFor('fr'), 'Dragon Blanc aux Yeux Bleus');
    expect(ygo.card.nameFor('en'), 'Blue-Eyes White Dragon');
    expect((ygo.info as YgoCardInfo).setName, 'Legend of Blue Eyes White Dragon');
    expect(CardSearch.ygoFound({'id': 5, 'name': 'X', 'type': 'Spell Card', 'frameType': 'spell'}).card.id, 'YGO-5');
    expect(CardSearch.ygoRarity('Quarter Century Secret Rare'), Rarity.secretRare);
    expect(CardSearch.ygoRarity('Short Print'), Rarity.common);
  });

  test('a Yu-Gi-Oh! search filters high bounds and merges localized names', () async {
    final calls = <Map<String, String>>[];
    final search = CardSearch(pageSize: 2, client: MockClient((request) async {
      calls.add(request.url.queryParameters);
      final localized = request.url.queryParameters['language'] == 'fr';
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': [
              {'id': 1, 'name': localized ? 'Un' : 'One', 'type': 'Effect Monster', 'frameType': 'effect', 'atk': 1000, 'level': 4},
              {'id': 2, 'name': localized ? 'Deux' : 'Two', 'type': 'Effect Monster', 'frameType': 'effect', 'atk': 4000, 'level': 4},
            ]
          })),
          200);
    }));
    final found = await search.search(Game.ygo, const SearchQuery(text: 'x', atk: (0, 2000)), language: 'fr');
    expect(calls.map((c) => c['language']), [null, 'fr']);
    expect(calls.first['num'], '2');
    expect(found.cards.map((f) => f.card.nameFor('fr')), ['Un']);
    expect(found.hasMore, isTrue);
  });

  test('a Yu-Gi-Oh! search finds a card by its French name too', () async {
    final calls = <Map<String, String>>[];
    final search = CardSearch(pageSize: 2, client: MockClient((request) async {
      final params = request.url.queryParameters;
      calls.add(params);
      Map<String, Object> card(int id, String name) =>
          {'id': id, 'name': name, 'type': 'Effect Monster', 'frameType': 'effect', 'atk': 1000, 'level': 4};
      final data = switch ((params['language'], params['fname'], params['id'])) {
        // Nothing in English is named like the French word...
        (null, 'sombre', null) => null,
        // ...two cards are in French...
        ('fr', 'sombre', null) => [card(1, 'Magicien Sombre'), card(2, 'Sombre Paladin')],
        // ...and they are fetched in English by passcode.
        (null, null, '1,2') => [card(1, 'Dark Magician'), card(2, 'Dark Paladin')],
        _ => throw StateError('unexpected $params'),
      };
      return data == null
          ? http.Response('{"error":"No card matching your query was found"}', 400)
          : http.Response.bytes(utf8.encode(jsonEncode({'data': data})), 200);
    }));
    final found = await search.search(Game.ygo, const SearchQuery(text: 'sombre'), language: 'fr');
    expect(calls.length, 3);
    expect(calls.last.containsKey('fname'), isFalse, reason: 'by passcode alone');
    expect(found.cards.map((f) => f.card.nameFor('en')), ['Dark Magician', 'Dark Paladin']);
    expect(found.cards.map((f) => f.card.nameFor('fr')), ['Magicien Sombre', 'Sombre Paladin']);
    expect(found.hasMore, isFalse, reason: 'the English page was empty');
  });

  test('a Magic search asks Scryfall for the English names behind a French one', () async {
    String? q;
    final search = CardSearch(client: MockClient((request) async {
      q = request.url.queryParameters['q'];
      return http.Response('{"code":"not_found"}', 404);
    }));
    const names = {'Llanowar Elves': 'Elfes de Llanowar', 'Elvish Mystic': 'Mystique elfe', 'Giant Growth': 'Croissance gigantesque'};
    expect(CardSearch.englishNamesFor('elf', names), ['Llanowar Elves', 'Elvish Mystic']);
    expect(CardSearch.englishNamesFor('  ', names), isEmpty);
    await search.search(Game.mtg, const SearchQuery(text: 'elf', types: {'Creature'}), frenchNames: names);
    expect(q, '(elf or !"Llanowar Elves" or !"Elvish Mystic") t:creature');
    // Without a French match, the text goes as it is.
    await search.search(Game.mtg, const SearchQuery(text: 'zzz'), frenchNames: names);
    expect(q, 'zzz');
  });

  test('a Scryfall search with no match is an empty result, not an error', () async {
    final search = CardSearch(client: MockClient((_) async => http.Response('{"code":"not_found"}', 404)));
    final found = await search.search(Game.mtg, const SearchQuery(text: 'zzz'));
    expect(found.cards, isEmpty);
    expect(found.hasMore, isFalse);
  });
}
