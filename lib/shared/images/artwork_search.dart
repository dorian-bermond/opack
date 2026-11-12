import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/catalog/domain/models.dart';

/// One picture a card can be shown with: its [key] (see
/// [CardData.artwork]), a [label] naming the scan, and whether it is the
/// card's own print.
typedef Artwork = ({String key, String label, bool own});

/// Lists every scan a card exists with, as the errata chooser lists every
/// text version. MtG: every print of the card on Scryfall, in every
/// language. Yu-Gi-Oh!: every scan on the Yu-Gi-Oh! wiki (each set, region,
/// rarity and edition), then YGOPRODeck's pictures (alternate artworks).
class ArtworkSearch {
  ArtworkSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {'User-Agent': 'Opack/1.0', 'Accept': 'application/json'};

  /// At most this many Scryfall pages (175 prints each).
  static const maxPages = 3;

  /// The scans of [card], its own first; empty when the card has no online
  /// key.
  Future<List<Artwork>> alternatives(CardData card) async {
    if (card.scryfallId case final id?) return _scryfall(id);
    if (card.passcode case final passcode?) {
      return _ownFirst([
        ...await _wikiScans(card),
        ...await _ygoprodeck(passcode),
      ]);
    }
    return const [];
  }

  Future<List<Artwork>> _scryfall(String id) async {
    final card = await _getJson(Uri.https('api.scryfall.com', '/cards/$id'));
    if (card == null) return const [];
    final prints = switch (card['prints_search_uri']) {
      final String uri => Uri.parse(uri),
      _ => Uri.https('api.scryfall.com', '/cards/search', {
          'q': 'oracleid:${card['oracle_id']}',
          'unique': 'prints',
          'order': 'released',
        }),
    };
    // Every language of every print, each its own Scryfall card.
    var next = prints.replace(queryParameters: {
      ...prints.queryParameters,
      'include_multilingual': 'true',
    });
    final found = <Artwork>[];
    for (var page = 0; page < maxPages; page++) {
      final listing = await _getJson(next);
      if (listing == null) break;
      for (final print in (listing['data'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        if (print['id'] case final String printId) {
          final setName = print['set_name'] as String?;
          final lang = print['lang'] as String?;
          found.add((
            key: printId,
            label: [
              '${(print['set'] as String? ?? '').toUpperCase()} ${print['collector_number'] ?? ''}'.trim(),
              if (lang != null && lang != 'en') lang.toUpperCase(),
              ?setName,
            ].join(' · '),
            own: printId == id,
          ));
        }
      }
      if (listing['has_more'] != true || listing['next_page'] is! String) break;
      next = Uri.parse(listing['next_page'] as String);
    }
    return _ownFirst(found);
  }

  /// Every scan of the card on the Yu-Gi-Oh! wiki, named like
  /// `GearfriedtheIronKnight-CIBR-FR-C-1E.png`: one per set, region, rarity
  /// and edition. The card's own print is the scan of its print code.
  Future<List<Artwork>> _wikiScans(CardData card) async {
    final english = card.names['en'];
    if (english == null) return const [];
    final name = wikiFileName(english);
    final json = await _getJson(Uri.https('yugioh.fandom.com', '/api.php', {
      'action': 'query',
      'list': 'allimages',
      'aiprefix': '$name-',
      'aiprop': 'url',
      'ailimit': '500',
      'format': 'json',
    }));
    final files = (json?['query']?['allimages'] as List? ?? const []).cast<Map<String, dynamic>>();
    final ownPrint = RegExp(r'^([A-Z0-9]+)-([A-Z]{1,2})[A-Z]?\d').firstMatch(card.id);
    return [
      for (final file in files)
        if ((file['url'], file['name']) case (final String url, final String fileName))
          if (scanLabel(fileName, name) case final label?)
            (
              key: url,
              label: label,
              own: ownPrint != null &&
                  label.startsWith('${ownPrint.group(1)}-${ownPrint.group(2)}') &&
                  !label.contains('OP'),
            ),
    ];
  }

  /// `SET-REGION · RARITY · EDITION` from a wiki scan file name after the
  /// card's name, `null` for files of another card sharing the prefix.
  static String? scanLabel(String fileName, String name) {
    final rest = fileName.replaceAll(RegExp(r'\.\w+$'), '').substring(name.length + 1);
    final parts = rest.split('-');
    // SET-REGION at least; a longer first part is another card's name.
    if (parts.length < 2 || !RegExp(r'^[A-Z0-9]+$').hasMatch(parts[0])) return null;
    if (!RegExp(r'^[A-Z]{1,2}$').hasMatch(parts[1])) return null;
    return ['${parts[0]}-${parts[1]}', ...parts.skip(2)].join(' · ');
  }

  /// A card name as the wiki names its files: no parenthetical, letters
  /// and digits only.
  static String wikiFileName(String english) =>
      english.replaceAll(RegExp(r' \(.*\)$'), '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  Future<List<Artwork>> _ygoprodeck(String passcode) async {
    final number = int.tryParse(passcode);
    final json = await _getJson(Uri.https('db.ygoprodeck.com', '/api/v7/cardinfo.php',
        number == null ? {'name': passcode} : {'id': '$number'}));
    final card = (json?['data'] as List? ?? const []).cast<Map<String, dynamic>>().firstOrNull;
    if (card == null) return const [];
    final images = (card['card_images'] as List? ?? const []).cast<Map<String, dynamic>>();
    return [
      for (final (i, image) in images.indexed)
        if (image['id'] case final id?)
          (key: '$id', label: 'YGOPRODeck #${i + 1}', own: false),
    ];
  }

  static List<Artwork> _ownFirst(List<Artwork> found) =>
      [...found.where((a) => a.own), ...found.where((a) => !a.own)];

  Future<Map<String, dynamic>?> _getJson(Uri url) async {
    final http.Response response;
    try {
      response = await _client.get(url, headers: _headers);
    } on Exception {
      return null;
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw HttpException('${url.host} ${response.statusCode}');
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

/// `null` disables artwork swapping (tests).
final artworkSearchProvider = Provider<ArtworkSearch?>((ref) => ArtworkSearch());

/// What identifies a card online, the [artworksProvider] family key
/// (records compare by value, cards do not).
typedef ArtworkKey = ({String id, String? name, String? scryfallId, String? passcode});

ArtworkKey artworkKeyOf(CardData card) =>
    (id: card.id, name: card.names['en'], scryfallId: card.scryfallId, passcode: card.passcode);

/// The scans of a card, fetched once per card.
final artworksProvider = FutureProvider.family<List<Artwork>, ArtworkKey>((ref, key) async {
  final search = ref.watch(artworkSearchProvider);
  if (search == null) return const [];
  return search.alternatives(CardData(
    id: key.id,
    names: {'en': ?key.name},
    rarity: Rarity.common,
    scryfallId: key.scryfallId,
    passcode: key.passcode,
  ));
});
