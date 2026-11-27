import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/shared/images/card_image_cache.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('opack-images'));
  tearDown(() => dir.delete(recursive: true));

  test('MtG cards go to Scryfall, Yu-Gi-Oh! cards to YGOPRODeck', () {
    final mtg = cardImageSource(const CardData(
        id: 'DMU-1', names: {}, rarity: Rarity.common, scryfallId: 'abc'))!;
    expect(mtg.url.host, 'api.scryfall.com');
    expect(mtg.url.path, '/cards/abc');
    expect(mtg.fallback, isNull);
    final fr = cardImageSource(
        const CardData(id: 'DMU-187★', names: {}, rarity: Rarity.common, scryfallId: 'abc'),
        language: 'fr')!;
    expect(fr.key, 'scryfall-abc-fr');
    expect(Uri.decodeComponent(fr.url.path), '/cards/dmu/187★/fr');
    expect(fr.fallback, mtg);
    final ygo = cardImageSource(const CardData(
        id: 'CIBR-FR001', names: {}, rarity: Rarity.common, passcode: '92327802'))!;
    expect(ygo.url.toString(), 'https://images.ygoprodeck.com/images/cards/92327802.jpg');
    final ygoFr = cardImageSource(
        const CardData(
            id: 'CIBR-FR001',
            names: {'en': 'Ash Blossom & Joyous Spring'},
            rarity: Rarity.common,
            passcode: '92327802'),
        language: 'fr')!;
    expect(ygoFr.key, 'ygo-CIBR-FR001-fr');
    expect(ygoFr.url.host, 'yugioh.fandom.com');
    expect(ygoFr.url.queryParameters['aiprefix'], 'AshBlossomJoyousSpring-CIBR-FR-');
    expect(ygoFr.fallback, ygo);
    // Leading zeros are dropped for YGOPRODeck; a name-as-passcode goes through cardinfo.
    expect(cardImageSource(const CardData(id: 'ROTA-FR000', names: {}, rarity: Rarity.common, passcode: '03149401'))!.url.path, '/images/cards/3149401.jpg');
    final byName = cardImageSource(const CardData(id: 'DOOD-FR001', names: {'en': 'D/D Lance Soldier'}, rarity: Rarity.common, passcode: 'D/D Lance Soldier'))!;
    expect(byName.key, 'ygo-DOOD-FR001');
    expect(byName.url.path, '/api/v7/cardinfo.php');
    expect(byName.url.queryParameters['name'], 'D/D Lance Soldier');
    // Old one-letter regions and skill-card codes still find the wiki scan.
    expect(cardImageSource(const CardData(id: 'TP1-F001', names: {'en': 'Mechanicalchaser'}, rarity: Rarity.common, passcode: '7359741'), language: 'fr')!.url.queryParameters['aiprefix'], 'Mechanicalchaser-TP1-FR-');
    expect(cardImageSource(const CardData(id: 'STP3-FRS01', names: {'en': 'Cocoon of Ultra Evolution (Skill Card)'}, rarity: Rarity.common, passcode: 'x'), language: 'fr')!.url.queryParameters['aiprefix'], 'CocoonofUltraEvolution-STP3-FR-');
    // A French UI shows an English print's own scan, not a French one.
    expect(cardImageSource(const CardData(id: 'CIBR-EN001', names: {'en': 'X'}, rarity: Rarity.common, passcode: '1'), language: 'fr')!.fallback, isNull);
    expect(cardImageSource(const CardData(id: 'X', names: {}, rarity: Rarity.common)), isNull);
  });

  test('booster pictures: wiki pack scans for Yu-Gi-Oh!, card art for MtG', () {
    CardSet set(Game game, String code, List<CardData> cards, {String? prefix, String? name}) =>
        CardSet(code: code, game: game, names: {'en': ?name}, cards: cards, boosters: const {}, prefix: prefix);
    final ygo = boosterImageSource(set(Game.ygo, 'IOC2', const [], prefix: 'IOC'), language: 'fr')!;
    expect(ygo.key, 'booster-ygo-IOC2-fr');
    expect(ygo.url.queryParameters['aiprefix'], 'IOC-BoosterFR');
    expect(ygo.fallback!.url.queryParameters['aiprefix'], 'IOC-BoosterEN');
    expect(ygo.fallback!.fallback!.url.path, '/images/sets/IOC.jpg');
    expect(boosterImageSource(set(Game.ygo, 'CIBR', const []))!.url.queryParameters['aiprefix'], 'CIBR-BoosterEN');

    final mtg = boosterImageSource(set(Game.mtg, 'DMU', name: 'Dominaria United', const [
      CardData(id: 'DMU-1', names: {}, rarity: Rarity.rare, scryfallId: 'r'),
      CardData(id: 'DMU-2', names: {}, rarity: Rarity.mythic, scryfallId: 'm'),
      CardData(id: 'DMU-3', names: {}, rarity: Rarity.mythic),
    ]), booster: BoosterType.draft)!;
    expect(mtg.key, 'booster-mtg-DMU-draft', reason: 'a set without formulas keeps the requested type');
    expect(boosterImageSource(set(Game.mtg, 'DMU', const []))!.key, 'booster-mtg-DMU-standard');
    expect(mtg.url.host, 'mtg.wiki');
    expect(mtg.url.queryParameters['prop'], 'images');
    expect(mtg.url.queryParameters['titles'], 'Dominaria United');
    expect(mtg.fallback!.key, 'booster-mtg-DMU-art');
    expect(mtg.fallback!.url.path, '/cards/m');
    expect(mtg.fallback!.url.queryParameters['version'], 'art_crop');
    expect(boosterImageSource(set(Game.mtg, 'X', const []))!.fallback, isNull);

    // Page pictures as `prop=images` lists them.
    Map<String, dynamic> listing(List<String> titles) => {
          'query': {
            'pages': {
              '1': {
                'title': 'A set',
                'images': [for (final t in titles) {'title': 'File:$t'}],
              }
            }
          }
        };
    String? picked(List<String> titles, BoosterType? type) {
      final url = pickMtgBooster(listing(titles), type);
      if (url == null) return null;
      final query = Uri.parse(url).queryParameters;
      expect(query['prop'], 'imageinfo');
      expect(query['iiurlwidth'], '400');
      return query['titles']!.replaceFirst('File:', '');
    }
    const hob = ['HOB Box Topper Booster.jpg', 'HOB Collector Booster.png', 'HOB Play Booster 1.png', 'Hobbit logo.png'];
    expect(picked(hob, BoosterType.play), 'HOB Play Booster 1.png');
    expect(picked(hob, BoosterType.collector), 'HOB Collector Booster.png');
    expect(picked(hob, BoosterType.draft), 'HOB Play Booster 1.png', reason: 'collector packs come last');
    expect(picked(['ELD booster.png', 'ELD Collector Booster.png'], BoosterType.draft), 'ELD booster.png');
    expect(picked(['DMU booster box.png', 'DMU Welcome Booster.png', 'Dominaria United Logo.png', 'B.svg'], null),
        'Dominaria United Logo.png', reason: 'no booster: the set logo');
    expect(picked(['Innistrad werewolves provisional logo.png', 'MID bundle.png'], null), isNull);
    expect(picked(['Unlock booster codes.png', 'GRN booster.png'], BoosterType.draft), 'GRN booster.png');
    expect(picked(['2XM Booster sleeve.jpg', 'Mystery Booster cards.png'], BoosterType.draft), isNull);
    expect(picked(['THB Collector Boosters.png', 'THB booster.png'], BoosterType.draft), 'THB booster.png');
    expect(picked(['DGM 6 card booster.jpg', 'DGM booster.jpg'], BoosterType.draft), 'DGM booster.jpg');
    expect(picked(['TDM Collector Booster.png'], BoosterType.play), 'TDM Collector Booster.png',
        reason: 'the only booster, whatever its type');
    final named = pickMtgBooster(listing(['Logo Khans of Tarkir.png', 'Morph Overlay card.jpeg']), null,
        setName: 'Khans of Tarkir');
    expect(Uri.parse(named!).queryParameters['titles'], 'File:Logo Khans of Tarkir.png');
    final asName = pickMtgBooster(listing(['Eldritch Moon.png', 'Hanweir.png']), null, setName: 'Eldritch Moon');
    expect(Uri.parse(asName!).queryParameters['titles'], 'File:Eldritch Moon.png');
    final guilds = pickMtgBooster(listing(['Boros Logo.png', 'Dimir Logo.png', 'GRN Logo.jpg', 'Unlock booster codes.png']), null,
        setName: 'Guilds of Ravnica', setCode: 'GRN');
    expect(Uri.parse(guilds!).queryParameters['titles'], 'File:GRN Logo.jpg', reason: 'the set logo beats guild logos');
    final partial = pickMtgBooster(listing(['Lord of the Rings.png', 'LTR key art.jpg']), null,
        setName: 'The Lord of the Rings: Tales of Middle-earth', setCode: 'LTR');
    expect(Uri.parse(partial!).queryParameters['titles'], 'File:Lord of the Rings.png');
  });

  test('a render the app stored is fetched from the cache, never downloaded', () async {
    final cache = CardImageCache(Future.value(dir), client: MockClient((_) async => throw StateError('offline')));
    final stored = await cache.store('render-p-X-1-7', [1, 2, 3]);
    expect(stored.path, endsWith('render-p-X-1-7.png'));
    const card = CardData(id: 'X-1', names: {'en': 'X'}, rarity: Rarity.common, artwork: 'render:render-p-X-1-7');
    final source = cardImageSource(card)!;
    expect(source.key, 'render-p-X-1-7');
    expect(source.extension, 'png');
    expect(renderedArtworkKey(card.artwork), 'render-p-X-1-7');
    expect(renderedArtworkKey('12345'), isNull);
    final file = await cache.fetch(source.key, source.url, extension: source.extension);
    expect(await file!.readAsBytes(), [1, 2, 3]);
  });

  test('a failed on-demand thumbnail falls back to the full file', () async {
    final seen = <String>[];
    final cache = CardImageCache(Future.value(dir), client: MockClient((request) async {
      seen.add(request.url.path);
      if (request.url.queryParameters['prop'] == 'images') return http.Response('{"query":{"pages":{}}}', 200);
      if (request.url.queryParameters['prop'] == 'imageinfo') {
        return http.Response('{"query":{"pages":{"2":{"imageinfo":[{"thumbwidth":400,"url":"https://files.example.com/M15_logo.jpg"}]}}}}', 200);
      }
      if (request.url.path == '/thumb.php') return http.Response('', 400);
      return http.Response.bytes([5], 200);
    }));
    final file = await cache.fetch('m15', Uri.https('wiki.example.com', '/api.php', {'prop': 'images'}),
        pick: (_) => 'https://wiki.example.com/api.php?prop=imageinfo&titles=File%3AM15_logo.jpg&iiurlwidth=400');
    expect(await file!.readAsBytes(), [5]);
    expect(seen, ['/api.php', '/api.php', '/thumb.php', '/M15_logo.jpg']);
  });

  test('an imageinfo hop resolves the picked wiki file to its thumbnail', () async {
    final seen = <String>[];
    final cache = CardImageCache(Future.value(dir), client: MockClient((request) async {
      seen.add(request.url.queryParameters['prop'] ?? request.url.path);
      return switch (request.url.queryParameters['prop']) {
        'images' => http.Response('{"query":{"pages":{"1":{"images":[{"title":"File:HOB Play Booster 1.png"}]}}}}', 200),
        'imageinfo' => http.Response(
            '{"query":{"pages":{"2":{"imageinfo":[{"thumbwidth":${request.url.queryParameters['titles']!.contains('Small') ? 350 : 400},"url":"https://files.example.com/HOB_Play_Booster_1.png"}]}}}}',
            200),
        _ => http.Response.bytes([4], 200),
      };
    }));
    final file = await cache.fetch('hob', Uri.https('wiki.example.com', '/api.php', {'prop': 'images'}),
        pick: (listing) => pickMtgBooster(listing, BoosterType.play));
    expect(await file!.readAsBytes(), [4]);
    expect(seen, ['images', 'imageinfo', '/thumb.php'], reason: 'wide files go through thumb.php');

    seen.clear();
    await cache.fetch('small', Uri.https('wiki.example.com', '/api.php', {'prop': 'images'}),
        pick: (listing) => 'https://wiki.example.com/api.php?prop=imageinfo&titles=File%3ASmall.png&iiurlwidth=400');
    expect(seen, ['images', 'imageinfo', '/HOB_Play_Booster_1.png'], reason: 'small files are fetched as is');
  });

  test('downloads once, then serves the file from disk', () async {
    var hits = 0;
    final cache = CardImageCache(Future.value(dir), client: MockClient((request) async {
      hits++;
      return http.Response.bytes([1, 2, 3], 200);
    }));
    final url = Uri.parse('https://example.com/a.jpg');
    final first = await cache.fetch('a', url);
    expect(await first!.readAsBytes(), [1, 2, 3]);
    expect(await cache.fetch('a', url), isNotNull);
    expect(hits, 1);

    final again = CardImageCache(Future.value(dir), client: MockClient((_) async => throw StateError('offline')));
    expect(await again.fetch('a', url), isNotNull);
  });

  test('a failed download yields null and is not retried', () async {
    var hits = 0;
    final cache = CardImageCache(Future.value(dir), client: MockClient((request) async {
      hits++;
      throw const SocketException('offline');
    }));
    final url = Uri.parse('https://example.com/b.jpg');
    expect(await cache.fetch('b', url), isNull);
    expect(await cache.fetch('b', url), isNull);
    expect(hits, 1);
    expect(dir.listSync(), isEmpty);
  });

  test('falls back to the second URL when the first is missing', () async {
    final seen = <String>[];
    final cache = CardImageCache(Future.value(dir), client: MockClient((request) async {
      seen.add(request.url.path);
      return request.url.path == '/fr' ? http.Response('', 404) : http.Response.bytes([7], 200);
    }));
    final file = await cache.fetch('d', Uri.parse('https://example.com/fr'),
        fallback: ImageSource('en', Uri.parse('https://example.com/en')));
    expect(await file!.readAsBytes(), [7]);
    expect(seen, ['/fr', '/en']);
  });

  test('an allimages lookup downloads the first listed file, or falls back', () async {
    final seen = <String>[];
    final cache = CardImageCache(Future.value(dir), client: MockClient((request) async {
      seen.add(request.url.host + request.url.path);
      return switch (request.url.queryParameters['aiprefix']) {
        'Found-' => http.Response(
            '{"query":{"allimages":[{"name":"Found-SET-FR-C-1E-MISPRINT.png","url":"https://cdn.example.com/Misprint.png"},'
            '{"name":"Found-SET-FR-C-1E.png","url":"https://cdn.example.com/Found.png"}]}}',
            200),
        'Missing-' => http.Response('{"query":{"allimages":[]}}', 200),
        _ => http.Response.bytes([9], 200),
      };
    }));
    Uri lookup(String prefix) => Uri.https('wiki.example.com', '/api.php', {'list': 'allimages', 'aiprefix': prefix});
    final fallback = ImageSource('en', Uri.parse('https://en.example.com/x.jpg'));
    expect(await (await cache.fetch('found', lookup('Found-'), fallback: fallback))!.readAsBytes(), [9]);
    expect(await cache.fetch('missing', lookup('Missing-'), fallback: fallback), isNotNull);
    expect(seen, [
      'wiki.example.com/api.php',
      'cdn.example.com/Found.png',
      'wiki.example.com/api.php',
      'en.example.com/x.jpg',
    ]);
  });

  test('a cardinfo lookup downloads the first picture it lists', () async {
    final cache = CardImageCache(Future.value(dir), client: MockClient((request) async {
      if (request.url.path.endsWith('/cardinfo.php')) {
        return http.Response('{"data":[{"card_images":[{"image_url":"https://cdn.example.com/1.jpg"}]}]}', 200);
      }
      return http.Response.bytes([request.url.pathSegments.last.codeUnitAt(0)], 200);
    }));
    final file = await cache.fetch('n', Uri.https('db.example.com', '/api/v7/cardinfo.php', {'name': 'X'}));
    expect(await file!.readAsBytes(), ['1'.codeUnitAt(0)]);
  });

  test('a transient refusal serves the fallback without pinning it', () async {
    var refusals = 0;
    final cache = CardImageCache(Future.value(dir), client: MockClient((request) async {
      if (request.url.path == '/fr') {
        refusals++;
        return http.Response('', 503);
      }
      return http.Response.bytes([1], 200);
    }));
    final en = ImageSource('en', Uri.parse('https://example.com/en'));
    final file = await cache.fetch('fr', Uri.parse('https://example.com/fr'), fallback: en);
    expect(file!.path, endsWith('en.jpg'));
    expect(refusals, 2, reason: 'retried once');
    expect(File('${dir.path}/fr.jpg').existsSync(), isFalse);

    // A definite miss copies the fallback under the localized key.
    final missing = CardImageCache(Future.value(dir), client: MockClient((request) async =>
        request.url.path == '/fr' ? http.Response('', 404) : http.Response.bytes([1], 200)));
    await missing.fetch('fr', Uri.parse('https://example.com/fr'), fallback: en);
    expect(File('${dir.path}/fr.jpg').existsSync(), isTrue);
  });

  test('limits parallel downloads', () async {
    var active = 0, peak = 0;
    final cache = CardImageCache(Future.value(dir), parallel: 2, client: MockClient((request) async {
      active++;
      peak = peak < active ? active : peak;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      active--;
      return http.Response.bytes([0], 200);
    }));
    await Future.wait([
      for (var i = 0; i < 6; i++) cache.fetch('c$i', Uri.parse('https://c$i.example.com/c.jpg')),
    ]);
    expect(peak, 2);
  });
}
void main2() {}
