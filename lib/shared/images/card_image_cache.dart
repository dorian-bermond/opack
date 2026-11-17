import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../features/card_text/data/card_text_repository.dart';
import '../../features/catalog/domain/models.dart';

/// A picture to fetch under [key]: [url] first, then [fallback] if that fails.
/// When [url] answers a JSON listing rather than a picture, [pick] names the
/// picture to download from it (`null` when it lists none). Equal sources
/// share a [key].
class ImageSource {
  const ImageSource(this.key, this.url, {this.fallback, this.pick});

  final String key;
  final Uri url;
  final ImageSource? fallback;
  final String? Function(Map<String, dynamic> listing)? pick;

  @override
  bool operator ==(Object other) => other is ImageSource && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Where a card's picture comes from, in [language] when a scan of that print
/// exists, else in English. MtG: Scryfall, by set and collector number, then
/// by Scryfall id. Yu-Gi-Oh!: the Yu-Gi-Oh! wiki's scan of this print (found
/// through an `allimages` lookup, see [wikiScanLookup]), then YGOPRODeck by
/// passcode. `null` when the card has no usable key.
ImageSource? cardImageSource(CardData card, {String language = 'en'}) {
  // A chosen artwork is one precise picture: no language variant, no fallback.
  if (card.artwork case final artwork?) return artworkImageSource(card, artwork);
  if (card.scryfallId case final id?) {
    const query = {'format': 'image', 'version': 'normal'};
    final english = Uri.https('api.scryfall.com', '/cards/$id', query);
    if (language == 'en') return ImageSource('scryfall-$id', english);
    final [set, ...number] = card.id.split('-');
    return ImageSource(
      'scryfall-$id-$language',
      Uri.https('api.scryfall.com',
          '/cards/${set.toLowerCase()}/${number.join('-')}/$language', query),
      fallback: ImageSource('scryfall-$id', english),
    );
  }
  if (isOnePieceId(card.id)) {
    return ImageSource('opc-${card.id}', opcCardImage(card.id));
  }
  if (card.passcode case final passcode?) {
    // The importer stores the English name as passcode for cards without one;
    // YGOPRODeck can still find those by name.
    final english = switch (int.tryParse(passcode)) {
      final number? => ImageSource(
          'ygo-$number', Uri.https('images.ygoprodeck.com', '/images/cards/$number.jpg')),
      null => ImageSource('ygo-${card.id}',
          Uri.https('db.ygoprodeck.com', '/api/v7/cardinfo.php', {'name': passcode})),
    };
    final lookup = language == 'en' ? null : wikiScanLookup(card, language);
    if (lookup == null) return english;
    return ImageSource('ygo-${card.id}-$language', lookup, fallback: english);
  }
  return null;
}

/// Whether a card code is a One Piece one (`OP01-077`, `EB01-001`, `ST01-001`).
bool isOnePieceId(String id) => RegExp(r'^(OP|EB|ST|PRB|P)\d*-\d+').hasMatch(id);

/// optcgapi's picture of a One Piece card.
Uri opcCardImage(String id) => Uri.https('optcgapi.com', '/media/static/Card_Images/$id.jpg');

/// The picture of [artwork] for [card] (see [CardData.artwork]): a wiki scan
/// when it is a URL, else Scryfall's normal picture of that print for MtG,
/// YGOPRODeck's image for Yu-Gi-Oh!. With [small], the thumbnail instead
/// (for choosing among scans).
ImageSource artworkImageSource(CardData card, String artwork, {bool small = false}) {
  if (artwork.startsWith('http')) {
    final url = Uri.parse(artwork);
    // Fandom files: `…/File.png/revision/latest?cb=…`; a width-limited
    // thumbnail is made on demand under `revision/latest`.
    final revision = url.pathSegments.indexOf('revision');
    final file = revision > 0 ? url.pathSegments[revision - 1] : url.pathSegments.lastOrNull ?? artwork;
    final name = file.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final thumbnail = small && revision > 0 && url.pathSegments.length == revision + 2
        ? url.replace(pathSegments: [...url.pathSegments, 'scale-to-width-down', '200'])
        : url;
    return ImageSource(small ? 'scan-$name-small' : 'scan-$name', thumbnail);
  }
  if (card.scryfallId != null) {
    return ImageSource(
      small ? 'scryfall-$artwork-small' : 'scryfall-$artwork',
      Uri.https('api.scryfall.com', '/cards/$artwork',
          {'format': 'image', 'version': small ? 'small' : 'normal'}),
    );
  }
  return ImageSource(
    small ? 'ygo-$artwork-small' : 'ygo-$artwork',
    Uri.https('images.ygoprodeck.com', '/images/cards${small ? '_small' : ''}/$artwork.jpg'),
  );
}

/// The picture of a set's booster pack, in [language] when the wiki has that
/// region's pack, else English. Yu-Gi-Oh!: wiki `SET-BoosterFR.png` scans,
/// then YGOPRODeck's set image. MtG: the MTG Wiki's `SET_…_Booster` picture
/// for [booster] (see [pickMtgBooster]), else the art of the set's
/// highest-rarity card. `null` when nothing applies.
ImageSource? boosterImageSource(CardSet set, {String language = 'en', BoosterType? booster}) {
  switch (set.game) {
    case Game.mtg:
      final cover = set.cards.where((c) => c.scryfallId != null).fold<CardData?>(
          null, (best, c) => best == null || c.rarity.index > best.rarity.index ? c : best);
      final art = cover == null
          ? null
          : ImageSource(
              'booster-mtg-${set.code}-art',
              Uri.https('api.scryfall.com', '/cards/${cover.scryfallId}',
                  {'format': 'image', 'version': 'art_crop'}),
            );
      final type = set.boosterType(booster);
      return ImageSource(
        'booster-mtg-${set.code}-${type.name}',
        Uri.https('mtg.wiki', '/api.php', {
          'action': 'query',
          'prop': 'images',
          'titles': set.nameFor('en'),
          'imlimit': '500',
          'redirects': '1',
          'format': 'json',
        }),
        pick: (listing) =>
            pickMtgBooster(listing, type, setName: set.nameFor('en'), setCode: set.displayCode),
        fallback: art,
      );
    case Game.opc:
      // No pack scans online: the set's leader, or its best card, stands in.
      final cover = set.cards.where((c) => c.rarity == Rarity.leader).firstOrNull ??
          set.cards.fold<CardData?>(null, (best, c) => best == null || c.rarity.index > best.rarity.index ? c : best);
      return cover == null ? null : ImageSource('booster-opc-${set.code}', opcCardImage(cover.id));
    case Game.ygo:
      final code = set.displayCode;
      Uri wiki(String region) => Uri.https('yugioh.fandom.com', '/api.php', {
            'action': 'query',
            'list': 'allimages',
            'aiprefix': '$code-Booster$region',
            'aiprop': 'url',
            'format': 'json',
          });
      final english = ImageSource(
        'booster-ygo-${set.code}',
        wiki('EN'),
        fallback: ImageSource('booster-ygo-${set.code}-ygoprodeck',
            Uri.https('images.ygoprodeck.com', '/images/sets/$code.jpg')),
      );
      final region = _wikiRegions[language]?.first;
      if (region == null || region == 'EN') return english;
      return ImageSource('booster-ygo-${set.code}-$language', wiki(region), fallback: english);
  }
}

/// Among the pictures on a set's MTG Wiki page (a `prop=images` listing),
/// the booster for [booster]: a file named like `MKM Play Booster.png`,
/// preferring the requested type, then a plain `SET booster`, then another
/// type (collector last); never boxes, tins, sleeves or promos. Without one,
/// the set's logo: a `… logo.png`, or a file named after [setName]. The
/// result is an `imageinfo` query for that file's 400 px thumbnail (see
/// [wikiThumbnail]), or `null`.
String? pickMtgBooster(Map<String, dynamic> listing, BoosterType? booster,
    {String? setName, String? setCode}) {
  final pages = (listing['query']?['pages'] as Map<String, dynamic>? ?? const {}).values;
  final files = <({String name, String title})>[
    for (final page in pages.cast<Map<String, dynamic>>())
      for (final image in (page['images'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (image['title'] case final String title)
          (name: title.replaceFirst('File:', '').toLowerCase().replaceAll(' ', '_'), title: title),
  ];
  final boosters = files.where((f) =>
      f.name.contains('booster') &&
      !RegExp(r'box|welcome|jumpstart|tin|theme|advert|sample|prerelease|topper|display|case|'
              r'sleeve|codes|cards|treasure|chest|paperboard|sticker|wrapper')
          .hasMatch(f.name)).toList();
  if (boosters.isEmpty) {
    String squash(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final named = setName == null ? null : squash(setName);
    final code = setCode?.toLowerCase();
    String base(({String name, String title}) f) => squash(f.name.replaceAll(RegExp(r'\.\w+$'), ''));
    // The set's own logo (by code or name) beats other logos on the page,
    // such as guild logos; a file simply named after the set also counts.
    final logos = files.where((f) => f.name.contains('logo') && !f.name.contains('provisional')).toList();
    final own = logos.where((f) =>
        (code != null && f.name.contains(code)) ||
        (named != null && (named.contains(base(f).replaceAll('logo', '')) || base(f).contains(named))));
    final asName = files.where((f) =>
        named != null && base(f).length >= 6 && (base(f) == named || named.contains(base(f))));
    final first = own.firstOrNull ?? asName.firstOrNull ?? logos.firstOrNull;
    return first == null ? null : wikiThumbnail(first);
  }
  final wanted = switch (booster) {
    BoosterType.play => 'play',
    BoosterType.draft => 'draft',
    BoosterType.set => 'set',
    BoosterType.collector => 'collector',
    BoosterType.standard || null => null,
  };
  // Lower is better: the requested type, a plain booster, another type,
  // and lastly collector packs, odd sizes and group shots.
  int rank(({String name, String title}) f) {
    bool has(String word) => f.name.contains(word);
    if (wanted != null && has('_${wanted}_')) return 0;
    if (has('collector') && wanted != 'collector') return 4;
    if (RegExp(r'6[_-]card|all_|boosters').hasMatch(f.name)) return 3;
    if (['play', 'draft', 'set'].any((t) => has('_${t}_'))) return 2;
    return 1;
  }

  final best = boosters.reduce((a, b) => rank(b) < rank(a) ? b : a);
  return wikiThumbnail(best);
}

/// An MTG Wiki query answering the 400 px thumbnail of one file (the file
/// itself when smaller); the cache follows it to the picture.
String wikiThumbnail(({String name, String title}) file) => Uri.https('mtg.wiki', '/api.php', {
      'action': 'query',
      'titles': file.title,
      'prop': 'imageinfo',
      'iiprop': 'url',
      'iiurlwidth': '400',
      'format': 'json',
    }).toString();

/// Wiki region codes found in print codes, per language.
const _wikiRegions = {
  'fr': ['FR', 'F'],
  'en': ['EN', 'E'],
  'de': ['DE', 'G'],
  'it': ['IT', 'I'],
  'es': ['SP', 'S'],
  'pt': ['PT', 'P'],
};

/// A Yu-Gi-Oh! wiki query listing the scans of this print in [language],
/// e.g. `GearfriedtheIronKnight-CIBR-FR…`; the cache downloads the first
/// file it returns. `null` when the print is not in that language.
Uri? wikiScanLookup(CardData card, String language) {
  final english = card.names['en'];
  final regions = _wikiRegions[language];
  final match = RegExp(r'^([A-Z0-9]+)-([A-Z]{1,2})[A-Z]?\d').firstMatch(card.id);
  if (english == null || regions == null || match == null) return null;
  if (!regions.contains(match.group(2))) return null;
  final name = english
      .replaceAll(RegExp(r' \(.*\)$'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  return Uri.https('yugioh.fandom.com', '/api.php', {
    'action': 'query',
    'list': 'allimages',
    'aiprefix': '$name-${match.group(1)}-${regions.first}-',
    'aiprop': 'url',
    'format': 'json',
  });
}

/// Downloads card pictures once and keeps them on disk. A failed download
/// (offline, unknown card) is remembered until the next launch so the UI
/// does not retry on every rebuild.
class CardImageCache {
  CardImageCache(this._directory, {http.Client? client, int parallel = 4})
      : _client = client ?? http.Client(),
        _slots = parallel;

  final Future<Directory> _directory;
  final http.Client _client;
  final _pending = <String, Future<File?>>{};
  final _failed = <String>{};
  final _queue = <Completer<void>>[];
  int _slots;

  static Future<Directory> defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/images');

  /// The cached file for [key], downloading [url] first if needed. When that
  /// is unavailable and a [fallback] is given, its own cached file instead;
  /// `null` when nothing could be had.
  ///
  /// The fallback is only copied under [key] when [url] definitely has no
  /// picture (404), so a transient refusal does not pin the fallback forever.
  Future<File?> fetch(String key, Uri url,
      {ImageSource? fallback, String? Function(Map<String, dynamic>)? pick, String extension = 'jpg'}) {
    if (_failed.contains(key)) return Future.value(null);
    return _pending.putIfAbsent(key, () {
      final loading = _load(key, url, fallback, pick, extension);
      loading.whenComplete(() {
        _pending.remove(key);
      });
      return loading;
    });
  }

  Future<File?> _load(String key, Uri url, ImageSource? fallback,
      String? Function(Map<String, dynamic>)? pick, String extension) async {
    final file = File('${(await _directory).path}/$key.$extension');
    if (await file.exists()) return file;
    final response = await _withSlot(() => _download(url, pick));
    if (response != null && response.statusCode == 200) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    }
    final fallbackFile = fallback == null
        ? null
        : await fetch(fallback.key, fallback.url,
            fallback: fallback.fallback, pick: fallback.pick, extension: extension);
    if (fallbackFile == null) {
      _failed.add(key);
      return null;
    }
    if (response?.statusCode == 404) await fallbackFile.copy(file.path);
    return fallbackFile;
  }

  /// Gets [url]; when it is a lookup ([pick] given, or a wiki `allimages`
  /// listing or YGOPRODeck `cardinfo` query), gets the picture it points to,
  /// or answers 404 when it points to none. Rate limiting (429) and server
  /// errors are retried once; `null` when the network failed altogether.
  Future<http.Response?> _download(Uri url, String? Function(Map<String, dynamic>)? pick) async {
    try {
      final lookup = pick ??
          (url.queryParameters['list'] == 'allimages'
              ? _wikiScan
              : url.path.endsWith('/cardinfo.php')
                  ? _ygoprodeckPicture
                  : null);
      if (lookup == null) return await _getWithRetry(url);
      final listing = await _getWithRetry(url);
      if (listing.statusCode != 200) return listing;
      var picture = lookup(jsonDecode(listing.body) as Map<String, dynamic>);
      if (picture == null) return http.Response('', 404);
      if (Uri.parse(picture).queryParameters['prop'] == 'imageinfo') {
        // A second hop: the picked file's thumbnail (see [wikiThumbnail]),
        // or the file itself when the wiki cannot make one.
        final info = await _getWithRetry(Uri.parse(picture));
        if (info.statusCode != 200) return info;
        final candidates = _imageInfoUrls(jsonDecode(info.body) as Map<String, dynamic>, Uri.parse(picture));
        if (candidates.isEmpty) return http.Response('', 404);
        http.Response? response;
        for (final candidate in candidates) {
          response = await _getWithRetry(Uri.parse(candidate));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) return response;
        }
        return response!;
      }
      final response = await _getWithRetry(Uri.parse(picture));
      return response.bodyBytes.isEmpty ? http.Response('', 502) : response;
    } on Exception {
      return null;
    }
  }

  Future<http.Response> _getWithRetry(Uri url) async {
    final first = await _get(url);
    if (first.statusCode != 429 && first.statusCode < 500) return first;
    await Future<void>.delayed(first.statusCode == 429 ? const Duration(seconds: 2) : const Duration(milliseconds: 500));
    return _get(url);
  }

  /// Keeps requests to one host at least [_hostGap] apart (Scryfall asks for
  /// 50 to 100 ms between calls).
  static const _hostGap = Duration(milliseconds: 120);
  final _nextSlotPerHost = <String, DateTime>{};

  Future<void> _throttle(Uri url) {
    final now = DateTime.now();
    final earliest = _nextSlotPerHost[url.host] ?? now;
    final at = earliest.isAfter(now) ? earliest : now;
    _nextSlotPerHost[url.host] = at.add(_hostGap);
    return Future<void>.delayed(at.difference(now));
  }

  Future<T> _withSlot<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  /// Prefers a plain scan (`…-RARITY-EDITION.png`) over proxies and misprints.
  static String? _wikiScan(Map<String, dynamic> json) {
    final files = (json['query']?['allimages'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (files.isEmpty) return null;
    final plain = RegExp(r'-[A-Za-z]+-(1E|UE|LE)\.\w+$');
    final pick = files.firstWhere(
      (f) => plain.hasMatch(f['name'] as String? ?? ''),
      orElse: () => files.first,
    );
    return pick['url'] as String?;
  }

  /// The picture of the first page of an `imageinfo` answer, best first: a
  /// thumbnail made on demand by the wiki's `thumb.php` when the file is
  /// wider than requested (the file host only keeps the sizes pages have
  /// already used), then the file itself.
  static List<String> _imageInfoUrls(Map<String, dynamic> json, Uri query) {
    final pages = (json['query']?['pages'] as Map<String, dynamic>? ?? const {}).values;
    final width = int.tryParse(query.queryParameters['iiurlwidth'] ?? '') ?? 0;
    for (final page in pages.cast<Map<String, dynamic>>()) {
      if (page case {'imageinfo': [{'url': final String url} && final Map<String, dynamic> info, ...]}) {
        if ((info['thumbwidth'] as num? ?? 0) < width) return [url];
        return [
          Uri.https(query.host, '/thumb.php', {
            'f': Uri.parse(url).pathSegments.last,
            'width': '$width',
          }).toString(),
          url,
        ];
      }
    }
    return const [];
  }

  static String? _ygoprodeckPicture(Map<String, dynamic> json) {
    if (json case {'data': [{'card_images': [{'image_url': final String url}, ...]}, ...]}) return url;
    return null;
  }

  Future<http.Response> _get(Uri url) async {
    await _throttle(url);
    return _client.get(url, headers: const {
      'User-Agent': 'Opack/1.0',
      'Accept': 'image/*',
    });
  }

  Future<void> _acquire() {
    if (_slots > 0) {
      _slots--;
      return Future.value();
    }
    final waiter = Completer<void>();
    _queue.add(waiter);
    return waiter.future;
  }

  void _release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _slots++;
    }
  }
}

/// `null` disables pictures altogether (tests).
final cardImageCacheProvider = Provider<CardImageCache?>(
  (ref) => CardImageCache(CardImageCache.defaultDirectory()),
);

/// Whether pictures may be downloaded; saved across launches, on by default.
final cardImagesEnabledProvider = NotifierProvider<CardImagesSetting, bool>(CardImagesSetting.new);

class CardImagesSetting extends Notifier<bool> {
  static const _key = 'cardImages';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool enabled) {
    ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    state = enabled;
  }
}

/// Whether hovering a card for a moment shows its picture large enough to
/// read; saved across launches, on by default.
final cardHoverPreviewProvider = NotifierProvider<CardHoverPreviewSetting, bool>(CardHoverPreviewSetting.new);

class CardHoverPreviewSetting extends Notifier<bool> {
  static const _key = 'cardHoverPreview';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool enabled) {
    ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    state = enabled;
  }
}

/// The picture at a [cardImageSource], or `null` when disabled or unreachable.
final cardImageProvider = FutureProvider.family<File?, ImageSource>((ref, source) async {
  final cache = ref.watch(cardImageCacheProvider);
  if (cache == null || !ref.watch(cardImagesEnabledProvider)) return null;
  return cache.fetch(source.key, source.url, fallback: source.fallback, pick: source.pick);
});
