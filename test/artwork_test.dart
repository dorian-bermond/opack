import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/cube/data/cube_repository.dart';
import 'package:opack/features/pools/data/artwork_language.dart';
import 'package:opack/features/pools/data/pool_repository.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/shared/images/artwork_picker.dart';
import 'package:opack/shared/images/artwork_search.dart';
import 'package:opack/shared/images/card_image_cache.dart';

import 'widget_test.dart' show MemoryCubeStore, MemoryPoolStore;

void main() {
  const mtg = CardData(id: 'DMU-1', names: {'en': 'A'}, rarity: Rarity.rare, scryfallId: 'abc');
  const ygo = CardData(
      id: 'CIBR-FR077', names: {'en': 'Gearfried the Iron Knight'}, rarity: Rarity.common, passcode: '00423705');
  const scan = 'https://static.wikia.nocookie.net/yugioh/images/a/ab/GearfriedtheIronKnight-CIBR-FR-C-1E.png'
      '/revision/latest?cb=1';

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

    // A wiki scan is fetched as given; its thumbnail is made on demand.
    final wiki = cardImageSource(ygo.withArtwork(scan), language: 'fr')!;
    expect(wiki.key, 'scan-GearfriedtheIronKnight-CIBR-FR-C-1E.png');
    expect(wiki.url.toString(), scan);
    final thumb = artworkImageSource(ygo, scan, small: true);
    expect(thumb.key, 'scan-GearfriedtheIronKnight-CIBR-FR-C-1E.png-small');
    expect(thumb.url.path, endsWith('/revision/latest/scale-to-width-down/200'));
    expect(thumb.url.queryParameters['cb'], '1');

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

  test('a pool keeps its own booster picture path', () {
    final pool = Pool.empty(Game.opc, name: 'p').withCover('C:/covers/x.png');
    expect(pool.cover, 'C:/covers/x.png');
    final reloaded = Pool.fromJson(jsonDecode(jsonEncode(pool.toJson())) as Map<String, dynamic>);
    expect(reloaded.cover, 'C:/covers/x.png');
    expect(reloaded.copyWith(name: 'q').cover, 'C:/covers/x.png', reason: 'kept by copyWith');
    expect(reloaded.withCover(null).cover, isNull);
    expect(reloaded.withCover(null).toJson().containsKey('cover'), isFalse);

    // A picture not shaped like a pack may be printed on one.
    expect(reloaded.coverPrinted, isFalse);
    final printed = reloaded.withCover('C:/covers/logo.png', printed: true);
    expect(printed.coverPrinted, isTrue);
    final printedBack = Pool.fromJson(jsonDecode(jsonEncode(printed.toJson())) as Map<String, dynamic>);
    expect(printedBack.coverPrinted, isTrue);
    expect(printedBack.copyWith(name: 'q').coverPrinted, isTrue, reason: 'kept by copyWith');
    expect(printedBack.withCover(null, printed: true).coverPrinted, isFalse, reason: 'nothing to print');
    expect(printedBack.withCover(null).toJson().containsKey('coverPrinted'), isFalse);
  });

  test('lists every Scryfall print of an MtG card in every language, its own first', () async {
    final search = ArtworkSearch(
      client: MockClient((request) async {
        if (request.url.path == '/cards/abc') {
          return http.Response(jsonEncode({
            'id': 'abc',
            'set': 'dmu',
            'collector_number': '1',
            'prints_search_uri': 'https://api.scryfall.com/cards/search?q=oracleid%3Ao1&unique=prints',
          }), 200);
        }
        if (request.url.path == '/cards/search' && request.url.queryParameters['page'] == null) {
          expect(request.url.queryParameters['include_multilingual'], 'true');
          expect(request.url.queryParameters['unique'], 'prints');
          return http.Response(jsonEncode({
            'has_more': true,
            'next_page': 'https://api.scryfall.com/cards/search?q=oracleid%3Ao1&unique=prints&page=2',
            'data': [
              {'id': 'old', 'set': 'lea', 'collector_number': '1', 'set_name': 'Alpha', 'lang': 'en'},
              {'id': 'abc', 'set': 'dmu', 'collector_number': '1', 'set_name': 'Dominaria United', 'lang': 'en'},
              {'id': 'abcfr', 'set': 'dmu', 'collector_number': '1', 'set_name': 'Dominaria United', 'lang': 'fr'},
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
    expect(found.map((a) => a.key), ['abc', 'old', 'abcfr', 'new']);
    expect(found.first.own, isTrue);
    expect(found[1].label, 'LEA 1 · Alpha');
    expect(found[2].label, 'DMU 1 · FR · Dominaria United');
    expect(found[3].label, 'PLST DMU-1');
    expect(found.map((a) => a.language), ['en', 'en', 'fr', 'en'], reason: 'English when Scryfall says nothing');
    expect(found.map((a) => a.samePrint), [true, false, true, false], reason: 'the own print in any language');

    // The picker shows the pictures' language first, then English, then the rest,
    // and marks the print the card is shown with.
    final groups = groupedByLanguage(found, preferred: 'fr');
    expect(groups.keys, ['fr', 'en']);
    expect(groups['fr']!.single.key, 'abcfr');
    expect(shownArtwork(found, language: 'fr')!.key, 'abcfr', reason: 'the own print in French');
    expect(shownArtwork(found, language: 'de')!.key, 'abc', reason: 'no German print: the own one');
    expect(shownArtwork(found, artwork: 'old', language: 'fr')!.key, 'old', reason: 'a chosen artwork');
    expect(groupedByLanguage(found, preferred: 'en').keys, ['en', 'fr']);
  });

  test('lists every wiki scan of a Yu-Gi-Oh! card, then YGOPRODeck pictures', () async {
    final search = ArtworkSearch(
      client: MockClient((request) async {
        if (request.url.host == 'yugioh.fandom.com') {
          expect(request.url.queryParameters['aiprefix'], 'GearfriedtheIronKnight-');
          return http.Response(jsonEncode({
            'query': {
              'allimages': [
                {'name': 'GearfriedtheIronKnight-PSV-EN-C-1E.png', 'url': 'https://w/PSV-EN.png'},
                {'name': 'GearfriedtheIronKnight-CIBR-FR-C-1E.png', 'url': scan},
                {'name': 'GearfriedtheIronKnight-CIBR-FR-OP.png', 'url': 'https://w/CIBR-FR-OP.png'},
                {'name': 'GearfriedtheIronKnight-JP-Anime-DM.png', 'url': 'https://w/anime.png'},
                {'name': 'GearfriedtheIronKnightSwordmaster-SOI-EN-C-1E.png', 'url': 'https://w/other.png'},
              ],
            },
          }), 200);
        }
        expect(request.url.queryParameters['id'], '423705');
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 423705,
              'card_images': [
                {'id': 423705, 'image_url': 'x'},
                {'id': 423706, 'image_url': 'y'},
              ],
            },
          ],
        }), 200);
      }),
    );
    final found = await search.alternatives(ygo);
    expect(found.map((a) => a.key), [scan, 'https://w/PSV-EN.png', 'https://w/CIBR-FR-OP.png', '423705', '423706']);
    expect(found.first.own, isTrue, reason: "the scan of the card's own print code");
    expect(found.map((a) => a.label), ['CIBR-FR · C · 1E', 'PSV-EN · C · 1E', 'CIBR-FR · OP', 'YGOPRODeck #1', 'YGOPRODeck #2']);
    expect(found.map((a) => a.language), ['fr', 'en', 'fr', 'en', 'en']);
    expect(found.map((a) => a.samePrint), [true, false, false, false, false], reason: 'the own set, no OP scan');
    expect(ArtworkSearch.scanLanguage('SDY-SP · C'), 'es');
    expect(ArtworkSearch.scanLanguage('SDY-JP · C'), 'ja');
    expect(ArtworkSearch.scanLanguage('SDY-AE · C'), 'en');
    expect(groupedByLanguage(found, preferred: 'fr').keys, ['fr', 'en']);
    expect(groupedByLanguage(found, preferred: 'de').keys, ['en', 'fr'], reason: 'no German scan');
  });

  test('scan file names of other cards sharing the prefix are left out', () {
    const name = 'GearfriedtheIronKnight';
    expect(ArtworkSearch.scanLabel('$name-CIBR-FR-C-1E.png', name), 'CIBR-FR · C · 1E');
    expect(ArtworkSearch.scanLabel('$name-TP1-FR.png', name), 'TP1-FR');
    expect(ArtworkSearch.scanLabel('${name}Swordmaster-SOI-EN-C-1E.png', name), isNull);
    expect(ArtworkSearch.scanLabel('$name-JP-Anime-DM.png', name), isNull);
    expect(ArtworkSearch.wikiFileName('Cocoon of Ultra Evolution (Skill Card)'), 'CocoonofUltraEvolution');
  });

  test('a card without an online key has no artworks; a missing card none either', () async {
    final search = ArtworkSearch(client: MockClient((_) async => http.Response('', 404)));
    expect(await search.alternatives(const CardData(id: 'X', names: {}, rarity: Rarity.common)), isEmpty);
    expect(await search.alternatives(mtg), isEmpty);
    expect(await search.alternatives(ygo), isEmpty);
  });

  group('artworks follow the pictures language', () {
    Artwork art(String key, String label, String? language, {bool own = false}) =>
        (key: key, label: label, own: own, language: language, samePrint: own);
    final prints = [
      art('abc', 'DMU 1 · Dominaria United', 'en', own: true),
      art('abcfr', 'DMU 1 · FR · Dominaria United', 'fr'),
      art('old', 'LEA 1 · Alpha', 'en'),
    ];
    final scans = [
      art('https://w/CIBR-FR-C-1E.png', 'CIBR-FR · C · 1E', 'fr', own: true),
      art('https://w/CIBR-EN-C-UE.png', 'CIBR-EN · C · UE', 'en'),
      art('https://w/CIBR-EN-C-1E.png', 'CIBR-EN · C · 1E', 'en'),
      art('https://w/PSV-EN-C-1E.png', 'PSV-EN · C · 1E', 'en'),
      art('https://w/PSV-FR-C.png', 'PSV-FR · C', 'fr'),
      art('423705', 'YGOPRODeck #1', 'en'),
    ];

    test('the same print in the other language, the same rarity and edition first', () {
      expect(artworkIn(prints, prints[0], 'fr')!.key, 'abcfr');
      expect(artworkIn(prints, prints[1], 'en')!.key, 'abc');
      expect(artworkIn(prints, prints[2], 'fr'), isNull, reason: 'Alpha has no French print');
      expect(artworkIn(scans, scans[0], 'en')!.key, 'https://w/CIBR-EN-C-1E.png');
      expect(artworkIn(scans, scans[3], 'fr')!.key, 'https://w/PSV-FR-C.png', reason: 'the set, whatever the edition');
      expect(artworkIn(scans, scans[5], 'fr'), isNull, reason: 'a YGOPRODeck picture has no language');
      expect(artworkIn(scans, scans[0], 'de'), isNull);
    });

    test('changing the language swaps the artworks of the previous one, in every pool', () async {
      const other = CardData(id: 'DMU-2', names: {'en': 'B'}, rarity: Rarity.rare, scryfallId: 'xyz');
      final store = MemoryPoolStore();
      final container = ProviderContainer(overrides: [
        poolStoreProvider.overrideWithValue(store),
        cubeStoreProvider.overrideWithValue(MemoryCubeStore()),
        poolSetsProvider.overrideWith((ref, key) async => const {}),
        artworkSearchProvider.overrideWithValue(_FakeSearch({mtg.id: prints})),
      ]);
      addTearDown(container.dispose);
      final pools = container.read(poolsProvider.notifier);
      await pools.save(Pool.empty(Game.mtg, name: 'p', id: 'p')
          .withSource(const CardsSource([mtg, other]), cards: [mtg, other])
          .withArtwork(mtg.id, 'abcfr')
          .withArtwork(other.id, 'zzz'));
      await pools.save(Pool.empty(Game.mtg, name: 'q', id: 'q')
          .withSource(const CardsSource([mtg]), cards: [mtg])
          .withArtwork(mtg.id, 'old'));
      Future<Map<String, String>> artworksOf(String id) async =>
          (await container.read(poolsProvider.future)).firstWhere((p) => p.id == id).artworks;
      final languages = container.read(artworkLanguageSwitchProvider);

      // French to English: the own print again, so no choice is left; the
      // card whose prints cannot be fetched keeps its artwork.
      expect(await languages.run(from: 'fr', to: 'en'), 1);
      expect(await artworksOf('p'), {'DMU-2': 'zzz'});
      expect(await artworksOf('q'), {'DMU-1': 'old'}, reason: 'not a French artwork');

      // English to French: Alpha has no French print and stays.
      expect(await languages.run(from: 'en', to: 'fr'), 0);
      expect(await artworksOf('q'), {'DMU-1': 'old'});
      expect(await languages.run(from: 'fr', to: 'fr'), 0);
    });
  });
}

/// Answers the scans it was given, and fails like a refused request for
/// any other card.
class _FakeSearch extends ArtworkSearch {
  _FakeSearch(this.found);

  final Map<String, List<Artwork>> found;

  @override
  Future<List<Artwork>> alternatives(CardData card) async =>
      found[card.id] ?? (throw const FormatException('refused'));
}
