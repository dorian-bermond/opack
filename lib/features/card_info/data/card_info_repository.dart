import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../catalog/domain/models.dart';
import '../domain/card_info.dart';
import 'dotgg_one_piece.dart';

/// Card details per pool, one JSON file each (a card in two pools is saved
/// twice, so a pool is self-contained).
class CardInfoStore {
  CardInfoStore(this._directory);

  final Future<Directory> _directory;

  static Future<Directory> defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/pools/cards');

  Future<File> _file(String poolId) async => File('${(await _directory).path}/$poolId.json');

  Future<Map<String, CardInfo>> load(String poolId) async {
    final file = await _file(poolId);
    if (!await file.exists()) return {};
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return {
        for (final MapEntry(:key, :value) in json.entries)
          key: CardInfo.fromJson(value as Map<String, dynamic>),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> save(String poolId, Map<String, CardInfo> infos) async {
    final file = await _file(poolId);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      for (final MapEntry(:key, :value) in infos.entries) key: value.toJson(),
    }));
  }

  Future<void> delete(String poolId) async {
    final file = await _file(poolId);
    if (await file.exists()) await file.delete();
  }
}

/// Downloads card details: Scryfall's collection endpoint for MtG (75 ids a
/// call), YGOPRODeck's card info for Yu-Gi-Oh! (by passcode, in [language]
/// when it has it).
class CardInfoFetcher {
  CardInfoFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {'User-Agent': 'Opack/1.0', 'Accept': 'application/json'};

  /// Details keyed by card id for every card found.
  Future<Map<String, CardInfo>> fetch(Game game, List<CardData> cards, {String language = 'en'}) =>
      switch (game) {
        Game.mtg => _fetchMtg(cards),
        Game.ygo => _fetchYgo(cards, language),
        Game.opc => _fetchOpc(cards),
      };

  /// One Piece details come from onepiece.gg's full list, loaded once.
  Future<Map<String, CardInfo>> _fetchOpc(List<CardData> cards) async {
    final rows = await DotggOnePiece.rows(_client);
    // By print id, so an alternate art (`OP17-001_p1`) gets its details too.
    final byId = {for (final row in rows) '${row['id']}': row};
    return {
      for (final card in cards)
        if (byId[card.id] case final row?) card.id: OpcCardInfo.fromDotgg(row),
    };
  }

  Future<Map<String, CardInfo>> _fetchMtg(List<CardData> cards) async {
    final byScryfallId = <String, List<CardData>>{};
    for (final card in cards) {
      if (card.scryfallId case final id?) (byScryfallId[id] ??= []).add(card);
    }
    final result = <String, CardInfo>{};
    final ids = byScryfallId.keys.toList();
    for (var start = 0; start < ids.length; start += 75) {
      final chunk = ids.sublist(start, (start + 75).clamp(0, ids.length));
      final response = await _client.post(
        Uri.https('api.scryfall.com', '/cards/collection'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifiers': [for (final id in chunk) {'id': id}],
        }),
      );
      if (response.statusCode != 200) throw HttpException('Scryfall ${response.statusCode}');
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      for (final card in (json['data'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final info = MtgCardInfo.fromScryfall(card);
        for (final owner in byScryfallId[card['id'] as String] ?? const <CardData>[]) {
          result[owner.id] = info;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return result;
  }

  Future<Map<String, CardInfo>> _fetchYgo(List<CardData> cards, String language) async {
    final byPasscode = <String, List<CardData>>{};
    for (final card in cards) {
      final passcode = card.passcode;
      if (passcode != null && int.tryParse(passcode) != null) {
        (byPasscode['${int.parse(passcode)}'] ??= []).add(card);
      }
    }
    final result = <String, CardInfo>{};
    final ids = byPasscode.keys.toList();
    for (var start = 0; start < ids.length; start += 50) {
      final chunk = ids.sublist(start, (start + 50).clamp(0, ids.length));
      var found = await _ygoCards(chunk, language);
      // A chunk fails as a whole when one passcode is unknown: retry one by one.
      if (found == null) {
        found = [];
        for (final id in chunk) {
          found.addAll(await _ygoCards([id], language) ?? const []);
        }
      }
      for (final card in found) {
        final passcode = '${card['id']}';
        for (final owner in byPasscode[passcode] ?? const <CardData>[]) {
          result[owner.id] = YgoCardInfo.fromYgoprodeck(card, printCode: owner.id);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return result;
  }

  /// The cards YGOPRODeck knows among [ids]; `null` when it refused the
  /// query (unknown id) rather than when the list is empty.
  Future<List<Map<String, dynamic>>?> _ygoCards(List<String> ids, String language) async {
    final response = await _client.get(
      Uri.https('db.ygoprodeck.com', '/api/v7/cardinfo.php', {
        'id': ids.join(','),
        'misc': 'yes',
        if (language != 'en') 'language': language,
      }),
      headers: _headers,
    );
    if (response.statusCode == 400) return null;
    if (response.statusCode != 200) throw HttpException('YGOPRODeck ${response.statusCode}');
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (json['data'] as List? ?? const []).cast<Map<String, dynamic>>();
  }
}

final cardInfoStoreProvider =
    Provider<CardInfoStore>((ref) => CardInfoStore(CardInfoStore.defaultDirectory()));

/// `null` disables downloads (tests).
final cardInfoFetcherProvider = Provider<CardInfoFetcher?>((ref) => CardInfoFetcher());

/// What a pool knows about its cards, and whether a download is under way.
class CardInfoState {
  const CardInfoState({required this.infos, this.fetching = false, this.failed = false});

  final Map<String, CardInfo> infos;
  final bool fetching;

  /// The last download failed (offline?); the user may retry.
  final bool failed;

  CardInfoState copyWith({Map<String, CardInfo>? infos, bool? fetching, bool? failed}) =>
      CardInfoState(
        infos: infos ?? this.infos,
        fetching: fetching ?? this.fetching,
        failed: failed ?? this.failed,
      );
}

/// The card details saved for one pool, by pool id.
final poolCardInfoProvider =
    AsyncNotifierProvider.family<PoolCardInfo, CardInfoState, String>(PoolCardInfo.new);

class PoolCardInfo extends AsyncNotifier<CardInfoState> {
  PoolCardInfo(this.poolId);

  final String poolId;

  @override
  Future<CardInfoState> build() async =>
      CardInfoState(infos: await ref.watch(cardInfoStoreProvider).load(poolId));

  /// Downloads the details of the cards of [cards] not saved yet, in
  /// [language], and keeps them. Does nothing while a download runs or when
  /// downloads are disabled.
  Future<void> fetchMissing(Game game, List<CardData> cards, {required String language}) async {
    final fetcher = ref.read(cardInfoFetcherProvider);
    final current = state.value;
    if (fetcher == null || current == null || current.fetching) return;
    final missing = [for (final card in cards) if (!current.infos.containsKey(card.id)) card];
    if (missing.isEmpty) return;
    state = AsyncData(current.copyWith(fetching: true, failed: false));
    try {
      final fetched = await fetcher.fetch(game, missing, language: language);
      final infos = {...current.infos, ...fetched};
      await ref.read(cardInfoStoreProvider).save(poolId, infos);
      state = AsyncData(CardInfoState(infos: infos));
    } catch (_) {
      state = AsyncData(current.copyWith(fetching: false, failed: true));
    }
  }

  /// Keeps details that came with the cards themselves (an online search).
  Future<void> addInfos(Map<String, CardInfo> infos) async {
    final current = state.value ?? const CardInfoState(infos: {});
    final merged = {...current.infos, ...infos};
    await ref.read(cardInfoStoreProvider).save(poolId, merged);
    state = AsyncData(current.copyWith(infos: merged));
  }

  /// Forgets every detail (to download again, e.g. in another language).
  Future<void> clear() async {
    await ref.read(cardInfoStoreProvider).delete(poolId);
    state = const AsyncData(CardInfoState(infos: {}));
  }
}
