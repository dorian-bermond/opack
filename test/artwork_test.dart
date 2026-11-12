import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/shared/images/artwork_search.dart';
import 'package:opack/shared/images/card_image_cache.dart';

void main() {
  const mtg = CardData(id: 'DMU-1', names: {'en': 'A'}, rarity: Rarity.rare, scryfallId: 'abc');
  const ygo = CardData(id: 'CIBR-EN001', names: {'en': 'B'}, rarity: Rarity.common, passcode: '89631139');

  test('a chosen artwork replaces the picture, in every language, without fallback', () {
    final own = cardImageSource(mtg, language: 'fr')!;
    expect(own.fallback, isNotNull);

    final swapped = cardImageSource(mtg.withArtwork('def'), language: 'fr')!;
    expect(swapped.key, 'scryfall-def');
    expect(swapped.url.path, '/cards/def');
    expect(swapped.url.queryParameters['version'], 'normal');
    expect(swapped.fallback, isNull);

    final ygoSwapped = cardImageSource(ygo.withArtwork('89631140'), language: 'fr')!;
    expect(ygoSwapped.url.toString(), 'https://images.ygoprodeck.com/images/cards/89631140.jpg');
    expect(artworkImageSource(ygo, '89631140', small: true).url.path, '/images/cards_small/89631140.jpg');
    expect(artworkImageSource(mtg, 'def', small: true).url.queryParameters['version'], 'small');

    // Clearing restores the card's own print, and the foil flag survives.
    expect(mtg.withArtwork('def').withArtwork(null).artwork, isNull);
    expect(mtg.asFoil().withArtwork('def').foil, isTrue);
    expect(mtg.withArtwork('def').asFoil().artwork, 'def');
  });

  test('a pool remembers its artworks and applies them when resolved', () {
    var pool = Pool.empty(Game.mtg, name: 'p').withSource(const CardsSource([mtg]), cards: [mtg]);
    pool = pool.withArtwork(mtg.id, 'def');
    expect(pool.artworks, {'DMU-1': 'def'});

    final reloaded = Pool.fromJson(jsonDecode(jsonEncode(pool.toJson())) as Map<String, dynamic>);
    expect(reloaded.artworks, {'DMU-1': 'def'});
    expect(reloaded.withArtwork(mtg.id, null).artworks, isEmpty);
    expect(reloaded.withArtwork(mtg.id, null).toJson().containsKey('artworks'), isFalse);

    final play = PlayPool.resolve(reloaded, sets: const {}, cubes: const {});
    expect(play.entries.single.card.artwork, 'def');
    expect(play.entries.single.card.id, 'DMU-1');
    expect(play.tagCards[rarityTag(Rarity.rare)]!.single.artwork, 'def');
  });

  test('lists every Scryfall print of an MtG card, its own first', () async {
    final search = ArtworkSearch(
      client: MockClient((request) async {
        if (request.url.path == '/cards/abc') {
          return http.Response(jsonEncode({
            'id': 'abc',
            'prints_search_uri': 'https://api.scryfall.com/cards/search?q=oracleid%3Ao1&unique=prints',
          }), 200);
        }
        if (request.url.path == '/cards/search' && request.url.queryParameters['page'] == null) {
          return http.Response(jsonEncode({
            'has_more': true,
            'next_page': 'https://api.scryfall.com/cards/search?q=oracleid%3Ao1&unique=prints&page=2',
            'data': [
              {'id': 'old', 'set': 'lea', 'collector_number': '1', 'set_name': 'Alpha'},
              {'id': 'abc', 'set': 'dmu', 'collector_number': '1', 'set_name': 'Dominaria United'},
            ],
          }), 200);
        }
        if (request.url.queryParameters['page'] == '2') {
          return http.Response(jsonEncode({
            'has_more': false,
            'data': [
              {'id': 'new', 'set': 'plst', 'collector_number': 'DMU-1'},
            ],
          }), 200);
        }
        return http.Response('', 404);
      }),
    );
    final found = await search.alternatives(mtg);
    expect(found.map((a) => a.key), ['abc', 'old', 'new']);
    expect(found.first.own, isTrue);
    expect(found[1].label, 'LEA 1 · Alpha');
    expect(found[2].label, 'PLST DMU-1');
  });

  test('lists every YGOPRODeck picture of a Yu-Gi-Oh! card', () async {
    final search = ArtworkSearch(
      client: MockClient((request) async {
        expect(request.url.queryParameters['id'], '89631139');
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 89631139,
              'card_images': [
                {'id': 89631140, 'image_url': 'x'},
                {'id': 89631139, 'image_url': 'y'},
              ],
            },
          ],
        }), 200);
      }),
    );
    final found = await search.alternatives(ygo);
    expect(found.map((a) => a.key), ['89631139', '89631140']);
    expect(found.first.own, isTrue);
    expect(found.last.label, '#1');
  });

  test('a card without an online key has no artworks; a missing card none either', () async {
    final search = ArtworkSearch(client: MockClient((_) async => http.Response('', 404)));
    expect(await search.alternatives(const CardData(id: 'X', names: {}, rarity: Rarity.common)), isEmpty);
    expect(await search.alternatives(mtg), isEmpty);
    expect(await search.alternatives(ygo), isEmpty);
  });
}
