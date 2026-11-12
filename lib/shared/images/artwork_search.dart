import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/catalog/domain/models.dart';

/// One picture a card can be shown with: its [key] (see
/// [CardData.artwork]), a [label] naming the print, and whether it is the
/// card's own print.
typedef Artwork = ({String key, String label, bool own});

/// Lists the artworks a card exists with: every print of the card on
/// Scryfall for MtG, every picture YGOPRODeck has for Yu-Gi-Oh!.
class ArtworkSearch {
  ArtworkSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {'User-Agent': 'Opack/1.0', 'Accept': 'application/json'};

  /// At most this many Scryfall pages (175 prints each).
  static const maxPages = 3;

  /// The artworks of [card], its own first; empty when the card has no
  /// online key.
  Future<List<Artwork>> alternatives(CardData card) async {
    if (card.scryfallId case final id?) return _scryfall(id);
    if (card.passcode case final passcode?) return _ygoprodeck(passcode);
    return const [];
  }

  Future<List<Artwork>> _scryfall(String id) async {
    final card = await _getJson(Uri.https('api.scryfall.com', '/cards/$id'));
    if (card == null) return const [];
    var next = switch (card['prints_search_uri']) {
      final String uri => Uri.parse(uri),
      _ => Uri.https('api.scryfall.com', '/cards/search', {
          'q': 'oracleid:${card['oracle_id']}',
          'unique': 'prints',
          'order': 'released',
        }),
    };
    final found = <Artwork>[];
    for (var page = 0; page < maxPages; page++) {
      final listing = await _getJson(next);
      if (listing == null) break;
      for (final print in (listing['data'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        if (print['id'] case final String printId) {
          final setName = print['set_name'] as String?;
          found.add((
            key: printId,
            label: [
              '${(print['set'] as String? ?? '').toUpperCase()} ${print['collector_number'] ?? ''}'.trim(),
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

  Future<List<Artwork>> _ygoprodeck(String passcode) async {
    final number = int.tryParse(passcode);
    final json = await _getJson(Uri.https('db.ygoprodeck.com', '/api/v7/cardinfo.php',
        number == null ? {'name': passcode} : {'id': '$number'}));
    final card = (json?['data'] as List? ?? const []).cast<Map<String, dynamic>>().firstOrNull;
    if (card == null) return const [];
    final images = (card['card_images'] as List? ?? const []).cast<Map<String, dynamic>>();
    return _ownFirst([
      for (final (i, image) in images.indexed)
        if (image['id'] case final id?)
          (key: '$id', label: '#${i + 1}', own: '$id' == '$number'),
    ]);
  }

  static List<Artwork> _ownFirst(List<Artwork> found) =>
      [...found.where((a) => a.own), ...found.where((a) => !a.own)];

  Future<Map<String, dynamic>?> _getJson(Uri url) async {
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw HttpException('${url.host} ${response.statusCode}');
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

/// `null` disables artwork swapping (tests).
final artworkSearchProvider = Provider<ArtworkSearch?>((ref) => ArtworkSearch());

/// The online keys of a card, the [artworksProvider] family key (records
/// compare by value, cards do not).
typedef ArtworkKey = ({String? scryfallId, String? passcode});

ArtworkKey artworkKeyOf(CardData card) => (scryfallId: card.scryfallId, passcode: card.passcode);

/// The artworks of a card, fetched once per card.
final artworksProvider = FutureProvider.family<List<Artwork>, ArtworkKey>((ref, key) async {
  final search = ref.watch(artworkSearchProvider);
  if (search == null) return const [];
  return search.alternatives(CardData(
    id: key.scryfallId ?? key.passcode ?? '',
    names: const {},
    rarity: Rarity.common,
    scryfallId: key.scryfallId,
    passcode: key.passcode,
  ));
});
