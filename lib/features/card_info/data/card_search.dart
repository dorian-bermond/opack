import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../catalog/domain/models.dart';
import '../domain/card_info.dart';

/// A card found online, ready to join a pool with its details.
typedef FoundCard = ({CardData card, CardInfo info});

/// What to look for: free text plus the same facets the editor filters on.
/// Unused facets stay empty.
class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.rarities = const {},
    this.colors = const {},
    this.types = const {},
    this.keywords = const {},
    this.setCode = '',
    this.manaValue,
    this.ygoTypes = const {},
    this.attributes = const {},
    this.race = '',
    this.archetype = '',
    this.level,
    this.atk,
    this.def,
  });

  final String text;
  final Set<Rarity> rarities;

  /// Color letters, `C` for colorless (MtG).
  final Set<String> colors;

  /// Card types such as `Creature` (MtG).
  final Set<String> types;
  final Set<String> keywords;
  final String setCode;
  final (int, int)? manaValue;

  /// YGOPRODeck card types such as `Effect Monster` or `Spell Card`.
  final Set<String> ygoTypes;
  final Set<String> attributes;
  final String race;
  final String archetype;
  final (int, int)? level;
  final (int, int)? atk;
  final (int, int)? def;

  SearchQuery copyWith({
    String? text,
    Set<Rarity>? rarities,
    Set<String>? colors,
    Set<String>? types,
    Set<String>? keywords,
    String? setCode,
    (int, int)? Function()? manaValue,
    Set<String>? ygoTypes,
    Set<String>? attributes,
    String? race,
    String? archetype,
    (int, int)? Function()? level,
    (int, int)? Function()? atk,
    (int, int)? Function()? def,
  }) =>
      SearchQuery(
        text: text ?? this.text,
        rarities: rarities ?? this.rarities,
        colors: colors ?? this.colors,
        types: types ?? this.types,
        keywords: keywords ?? this.keywords,
        setCode: setCode ?? this.setCode,
        manaValue: manaValue == null ? this.manaValue : manaValue(),
        ygoTypes: ygoTypes ?? this.ygoTypes,
        attributes: attributes ?? this.attributes,
        race: race ?? this.race,
        archetype: archetype ?? this.archetype,
        level: level == null ? this.level : level(),
        atk: atk == null ? this.atk : atk(),
        def: def == null ? this.def : def(),
      );

  bool get isEmpty =>
      text.trim().isEmpty &&
      rarities.isEmpty &&
      colors.isEmpty &&
      types.isEmpty &&
      keywords.isEmpty &&
      setCode.trim().isEmpty &&
      manaValue == null &&
      ygoTypes.isEmpty &&
      attributes.isEmpty &&
      race.trim().isEmpty &&
      archetype.trim().isEmpty &&
      level == null &&
      atk == null &&
      def == null;

  /// Scryfall search syntax for this query.
  String get scryfall {
    String any(String key, Iterable<String> values) =>
        values.length == 1 ? '$key:${values.first}' : '(${values.map((v) => '$key:$v').join(' or ')})';
    return [
      if (text.trim().isNotEmpty) text.trim(),
      if (rarities.isNotEmpty) any('r', rarities.map((r) => r.name)),
      if (colors.isNotEmpty) 'c:${colors.map((c) => c.toLowerCase()).join()}',
      if (types.isNotEmpty) any('t', types.map((t) => t.toLowerCase())),
      for (final keyword in keywords) 'kw:${keyword.replaceAll(' ', '-').toLowerCase()}',
      if (setCode.trim().isNotEmpty) 'set:${setCode.trim().toLowerCase()}',
      if (manaValue case (final min, final max)) ...['mv>=$min', 'mv<=$max'],
    ].join(' ');
  }

  /// YGOPRODeck query parameters; ranges keep their low bound only, the
  /// high bound is checked on the answers.
  Map<String, String> get ygoprodeck => {
        if (text.trim().isNotEmpty) 'fname': text.trim(),
        if (ygoTypes.isNotEmpty) 'type': ygoTypes.join(','),
        if (attributes.isNotEmpty) 'attribute': attributes.join(','),
        if (race.trim().isNotEmpty) 'race': race.trim(),
        if (archetype.trim().isNotEmpty) 'archetype': archetype.trim(),
        if (level case (final min, _)) 'level': 'gte$min',
        if (atk case (final min, _)) 'atk': 'gte$min',
        if (def case (final min, _)) 'def': 'gte$min',
      };
}

/// YGOPRODeck card types offered in the search.
const ygoSearchTypes = [
  'Normal Monster',
  'Effect Monster',
  'Flip Effect Monster',
  'Tuner Monster',
  'Fusion Monster',
  'Synchro Monster',
  'XYZ Monster',
  'Link Monster',
  'Pendulum Effect Monster',
  'Ritual Monster',
  'Spell Card',
  'Trap Card',
];

const ygoAttributes = ['DARK', 'LIGHT', 'EARTH', 'WATER', 'FIRE', 'WIND', 'DIVINE'];

const mtgSearchTypes = [
  'Creature', 'Instant', 'Sorcery', 'Artifact', 'Enchantment', 'Planeswalker', 'Land', 'Battle',
];

/// Searches cards online to add to a pool: Scryfall for MtG (first page,
/// 175 cards), YGOPRODeck for Yu-Gi-Oh! (first [pageSize]).
class CardSearch {
  CardSearch({http.Client? client, this.pageSize = 60}) : _client = client ?? http.Client();

  final http.Client _client;
  final int pageSize;

  static const _headers = {'User-Agent': 'Opack/1.0', 'Accept': 'application/json'};

  /// The cards matching [query] and whether more exist. MtG French names
  /// come from [frenchNames] (English name to French); Yu-Gi-Oh! names come
  /// in English and, when different, in [language].
  Future<({List<FoundCard> cards, bool hasMore})> search(
    Game game,
    SearchQuery query, {
    String language = 'en',
    Map<String, String> frenchNames = const {},
  }) =>
      switch (game) {
        Game.mtg => _scryfall(query, frenchNames),
        Game.ygo => _ygoprodeck(query, language),
        Game.opc => _opc(query),
      };

  /// Every One Piece card, loaded once from optcgapi (a call per set).
  List<FoundCard>? _opcAll;

  Future<({List<FoundCard> cards, bool hasMore})> _opc(SearchQuery query) async {
    final all = _opcAll ??= await _loadOpc();
    final text = query.text.trim().toLowerCase();
    final found = [
      for (final f in all)
        if (f.info case final OpcCardInfo info)
          if ((text.isEmpty || info.name.toLowerCase().contains(text) || (info.text ?? '').toLowerCase().contains(text)) &&
              (query.rarities.isEmpty || query.rarities.contains(f.card.rarity)) &&
              (query.colors.isEmpty || info.colors.any(query.colors.contains)) &&
              (query.types.isEmpty || query.types.contains(info.type)) &&
              (query.setCode.trim().isEmpty || f.card.id.toLowerCase().startsWith(query.setCode.trim().toLowerCase())) &&
              (query.manaValue == null || (info.cost != null && info.cost! >= query.manaValue!.$1 && info.cost! <= query.manaValue!.$2)))
            f,
    ];
    return (cards: found.take(pageSize * 3).toList(), hasMore: found.length > pageSize * 3);
  }

  Future<List<FoundCard>> _loadOpc() async {
    final listing = await _client.get(Uri.https('optcgapi.com', '/api/allSets/'), headers: _headers);
    if (listing.statusCode != 200) throw HttpException('optcgapi ${listing.statusCode}');
    final sets = (jsonDecode(utf8.decode(listing.bodyBytes)) as List).cast<Map<String, dynamic>>();
    final found = <FoundCard>[];
    final seen = <String>{};
    for (final set in sets) {
      final id = set['set_id'] as String? ?? '';
      final response = await _client.get(Uri.https('optcgapi.com', '/api/sets/$id/'), headers: _headers);
      if (response.statusCode != 200) continue;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! List) continue;
      for (final json in body.cast<Map<String, dynamic>>()) {
        if (opcFound(json) case final f? when seen.add(f.card.id)) found.add(f);
      }
    }
    return found;
  }

  /// An optcgapi card as a pool card: its code, English name and rarity.
  static FoundCard? opcFound(Map<String, dynamic> json) {
    final id = (json['card_set_id'] as String? ?? '').trim();
    if (id.isEmpty) return null;
    final info = OpcCardInfo.fromOptcg(json);
    return (
      card: CardData(id: id, names: {'en': info.name}, rarity: opcRarity(json['rarity'] as String?)),
      info: info,
    );
  }

  /// The app's rarity for an optcgapi rarity code.
  static Rarity opcRarity(String? code) => switch ((code ?? '').trim().toUpperCase()) {
        'C' => Rarity.common,
        'UC' => Rarity.uncommon,
        'R' => Rarity.rare,
        'SR' => Rarity.superRare,
        'L' => Rarity.leader,
        'SEC' || 'TR' => Rarity.secretRare,
        _ => Rarity.special,
      };

  Future<({List<FoundCard> cards, bool hasMore})> _scryfall(
      SearchQuery query, Map<String, String> frenchNames) async {
    final response = await _client.get(
      Uri.https('api.scryfall.com', '/cards/search', {
        'q': query.scryfall,
        'order': 'name',
        'unique': 'cards',
      }),
      headers: _headers,
    );
    if (response.statusCode == 404) return (cards: <FoundCard>[], hasMore: false);
    if (response.statusCode != 200) throw HttpException('Scryfall ${response.statusCode}');
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (
      cards: [
        for (final card in (json['data'] as List? ?? const []).cast<Map<String, dynamic>>())
          mtgFound(card, frenchNames: frenchNames),
      ],
      hasMore: json['has_more'] == true,
    );
  }

  Future<({List<FoundCard> cards, bool hasMore})> _ygoprodeck(SearchQuery query, String language) async {
    final english = await _ygoPage(query, null);
    if (english == null) return (cards: <FoundCard>[], hasMore: false);
    final localized = language == 'en' ? null : await _ygoPage(query, language);
    final namesByPasscode = {
      for (final card in localized ?? const <Map<String, dynamic>>[]) '${card['id']}': card['name'] as String,
    };
    bool within((int, int)? range, int? value) =>
        range == null || (value != null && value >= range.$1 && value <= range.$2);
    final cards = <FoundCard>[
      for (final card in english)
        if (within(query.level, card['level'] as int?) &&
            within(query.atk, card['atk'] as int?) &&
            within(query.def, card['def'] as int?))
          ygoFound(card, localizedName: namesByPasscode['${card['id']}'], language: language),
    ];
    return (cards: cards, hasMore: english.length >= pageSize);
  }

  /// One page of YGOPRODeck answers, `null` when nothing matched.
  Future<List<Map<String, dynamic>>?> _ygoPage(SearchQuery query, String? language) async {
    final response = await _client.get(
      Uri.https('db.ygoprodeck.com', '/api/v7/cardinfo.php', {
        ...query.ygoprodeck,
        'misc': 'yes',
        'num': '$pageSize',
        'offset': '0',
        'language': ?language,
      }),
      headers: _headers,
    );
    if (response.statusCode == 400) return null;
    if (response.statusCode != 200) throw HttpException('YGOPRODeck ${response.statusCode}');
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (json['data'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  /// A Scryfall card as a pool card: its print code, names, rarity, colors.
  static FoundCard mtgFound(Map<String, dynamic> json, {Map<String, String> frenchNames = const {}}) {
    final info = MtgCardInfo.fromScryfall(json);
    final name = json['name'] as String? ?? '';
    return (
      card: CardData(
        id: '${info.setCode}-${info.collectorNumber}',
        names: {'en': name, 'fr': ?frenchNames[name]},
        rarity: switch (json['rarity']) {
          'uncommon' => Rarity.uncommon,
          'rare' => Rarity.rare,
          'mythic' => Rarity.mythic,
          'special' || 'bonus' => Rarity.special,
          _ => Rarity.common,
        },
        colors: info.colors.join(),
        scryfallId: json['id'] as String?,
      ),
      info: info,
    );
  }

  /// A YGOPRODeck card as a pool card: the print code and rarity of its
  /// first printing (or the passcode alone), its English name and
  /// [localizedName].
  static FoundCard ygoFound(Map<String, dynamic> json, {String? localizedName, String language = 'en'}) {
    final passcode = '${json['id']}';
    final printing = (json['card_sets'] as List? ?? const []).cast<Map<String, dynamic>>().firstOrNull;
    final code = printing?['set_code'] as String? ?? 'YGO-$passcode';
    return (
      card: CardData(
        id: code,
        names: {
          'en': json['name'] as String? ?? '',
          language: ?localizedName,
        },
        rarity: ygoRarity(printing?['set_rarity'] as String? ?? ''),
        passcode: passcode,
      ),
      info: YgoCardInfo.fromYgoprodeck(json, printCode: code),
    );
  }

  /// The app's rarity for a YGOPRODeck rarity name, as the importer maps
  /// the wiki's.
  static Rarity ygoRarity(String name) {
    final r = name.toLowerCase();
    if (r.contains('secret') || r.contains('starlight') || r.contains('collector') ||
        r.contains('quarter century') || r.contains('premium gold')) {
      return Rarity.secretRare;
    }
    if (r.contains('ultra') || r.contains('ultimate') || r.contains('ghost') ||
        r.contains('holographic') || r.contains('platinum') || r.contains('gold')) {
      return Rarity.ultraRare;
    }
    if (r.contains('super') || r.contains('mosaic')) return Rarity.superRare;
    if (r.contains('common') || r.contains('short print') || r.contains('normal')) return Rarity.common;
    return Rarity.rare;
  }
}
