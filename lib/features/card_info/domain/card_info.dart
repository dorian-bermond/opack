
/// Downloaded details of one card of a pool, for sorting, filtering and
/// metrics: Scryfall data for MtG, YGOPRODeck data for Yu-Gi-Oh!.
sealed class CardInfo {
  const CardInfo();

  factory CardInfo.fromJson(Map<String, dynamic> json) => switch (json['game']) {
        'mtg' => MtgCardInfo.fromJson(json),
        'ygo' => YgoCardInfo.fromJson(json),
        'opc' => OpcCardInfo.fromJson(json),
        final game => throw FormatException('Unknown card info game $game'),
      };

  Map<String, Object?> toJson();

  /// The card name in the data's language.
  String get name;
}

/// One Piece colors, in the game's order.
const opcColors = ['Red', 'Green', 'Blue', 'Purple', 'Black', 'Yellow'];

/// One Piece card types.
const opcTypes = ['Leader', 'Character', 'Event', 'Stage'];

/// Details of a One Piece card, from optcgapi.com.
class OpcCardInfo extends CardInfo {
  const OpcCardInfo({
    required this.name,
    required this.type,
    this.colors = const [],
    this.cost,
    this.power,
    this.counter,
    this.life,
    this.attribute,
    this.subtypes = const [],
    this.text,
    this.setCode,
    this.setName,
  });

  factory OpcCardInfo.fromJson(Map<String, dynamic> json) => OpcCardInfo(
        name: json['name'] as String,
        type: json['type'] as String,
        colors: (json['colors'] as List? ?? const []).cast<String>(),
        cost: json['cost'] as int?,
        power: json['power'] as int?,
        counter: json['counter'] as int?,
        life: json['life'] as int?,
        attribute: json['attribute'] as String?,
        subtypes: (json['subtypes'] as List? ?? const []).cast<String>(),
        text: json['text'] as String?,
        setCode: json['setCode'] as String?,
        setName: json['setName'] as String?,
      );

  /// Reads an optcgapi card object.
  factory OpcCardInfo.fromOptcg(Map<String, dynamic> json) {
    int? number(Object? value) => switch (value) {
          final int n => n,
          final num n => n.toInt(),
          final String s => int.tryParse(s.trim()),
          _ => null,
        };
    final color = (json['card_color'] as String? ?? '').trim();
    final subtypes = (json['sub_types'] as String? ?? '').trim();
    return OpcCardInfo(
      name: (json['card_name'] as String? ?? '').trim(),
      type: (json['card_type'] as String? ?? '').trim(),
      colors: [for (final c in color.split('/')) if (c.trim().isNotEmpty) c.trim()],
      cost: number(json['card_cost']),
      power: number(json['card_power']),
      counter: number(json['counter_amount']),
      life: number(json['life']),
      attribute: (json['attribute'] as String?)?.trim(),
      // Subtypes come space-separated, multi-word ones too ("Straw Hat Crew").
      subtypes: subtypes.isEmpty ? const [] : _splitSubtypes(subtypes),
      text: json['card_text'] as String?,
      setCode: (json['card_set_id'] as String?)?.split('-').firstOrNull,
      setName: json['set_name'] as String?,
    );
  }

  /// Known multi-word One Piece types, so "Animal Straw Hat Crew" splits
  /// into "Animal" and "Straw Hat Crew".
  static const _multiWord = [
    'Straw Hat Crew', 'Heart Pirates', 'Kid Pirates', 'Whitebeard Pirates', 'Big Mom Pirates',
    'Animal Kingdom Pirates', 'Beast Pirates', 'Red Hair Pirates', 'Blackbeard Pirates', 'Donquixote Pirates',
    'Thriller Bark Pirates', 'Baroque Works', 'Impel Down', 'Revolutionary Army', 'Land of Wano',
    'Fish-Man', 'Alabasta', 'Navy', 'Seven Warlords of the Sea', 'The Four Emperors', 'Drum Kingdom',
    'Water Seven', 'Sky Island', 'Arlong Pirates', 'Buggy Pirates', 'Kuja Pirates', 'Foxy Pirates',
    'Sun Pirates', 'Cross Guild', 'Egghead', 'Minister', 'Punk Hazard', 'Dressrosa', 'Film',
    'Germa 66', 'Vinsmoke Family', 'The Tontattas', 'Mountain Bandits', 'Krieg Pirates', 'Black Cat Pirates',
    'Jaya', 'Scientist', 'Music', 'Giant', 'Mink Tribe', 'Lunarian', 'Smile', 'Homies', 'Flying Pirates',
    'Neo Navy', 'Gyro Pirates', 'Goa Kingdom', 'The House of Lambs', 'Alvida Pirates', 'Rumbar Pirates',
    'Bellamy Pirates', 'Barto Club', 'New Giant Pirates', 'Caribou Pirates', 'Fallen Monk Pirates',
    'Happo Navy', 'Ideo Pirates', 'Beautiful Pirates', 'Tonta Corps', 'Yonta Maria Grand Fleet',
    'Golden Lion Pirates', 'Mary Geoise', 'Celestial Dragons', 'Former Rocks Pirates', 'Roger Pirates',
    'Former Roger Pirates', 'Whitebeard Pirates Allies', 'Former Whitebeard Pirates', 'Former Navy',
    'Former Baroque Works', 'The Vinsmoke Family', 'Kozuki Clan', 'Kurozumi Clan', 'The Akazaya Nine',
    'Amazon Lily', 'Botanist', 'Shandian Warrior', 'Long Ring Long Land', 'Mugiwara Chase',
    'Eldoraggo Crew', 'Frost Moon Village', 'CP0', 'CP9', 'SWORD', 'Marine', 'Cipher Pol',
  ];

  static List<String> _splitSubtypes(String text) {
    final found = <String>[];
    var rest = text;
    for (final multi in _multiWord) {
      if (rest.contains(multi)) {
        found.add(multi);
        rest = rest.replaceAll(multi, ' ');
      }
    }
    found.addAll([for (final w in rest.split(RegExp(r'\s+'))) if (w.isNotEmpty) w]);
    return found;
  }

  @override
  Map<String, Object?> toJson() => {
        'game': 'opc',
        'name': name,
        'type': type,
        'colors': colors,
        'cost': ?cost,
        'power': ?power,
        'counter': ?counter,
        'life': ?life,
        'attribute': ?attribute,
        'subtypes': subtypes,
        'text': ?text,
        'setCode': ?setCode,
        'setName': ?setName,
      };

  @override
  final String name;

  /// Leader, Character, Event or Stage.
  final String type;
  final List<String> colors;
  final int? cost;
  final int? power;
  final int? counter;
  final int? life;
  final String? attribute;
  final List<String> subtypes;
  final String? text;
  final String? setCode;
  final String? setName;
}

/// Supertypes Scryfall puts before the card types on a type line.
const mtgSupertypes = {'Basic', 'Legendary', 'Ongoing', 'Snow', 'World', 'Host', 'Token'};

/// One face of an MtG card (most cards have one).
class MtgFace {
  const MtgFace({
    required this.name,
    this.manaCost,
    this.typeLine,
    this.text,
    this.flavor,
    this.power,
    this.toughness,
    this.loyalty,
    this.defense,
  });

  factory MtgFace.fromJson(Map<String, dynamic> json) => MtgFace(
        name: json['name'] as String? ?? '',
        manaCost: json['manaCost'] as String?,
        typeLine: json['typeLine'] as String?,
        text: json['text'] as String?,
        flavor: json['flavor'] as String?,
        power: json['power'] as String?,
        toughness: json['toughness'] as String?,
        loyalty: json['loyalty'] as String?,
        defense: json['defense'] as String?,
      );

  factory MtgFace.fromScryfall(Map<String, dynamic> json) => MtgFace(
        name: json['printed_name'] as String? ?? json['name'] as String? ?? '',
        manaCost: json['mana_cost'] as String?,
        typeLine: json['printed_type_line'] as String? ?? json['type_line'] as String?,
        text: json['printed_text'] as String? ?? json['oracle_text'] as String?,
        flavor: json['flavor_text'] as String?,
        power: json['power'] as String?,
        toughness: json['toughness'] as String?,
        loyalty: json['loyalty'] as String?,
        defense: json['defense'] as String?,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'manaCost': ?manaCost,
        'typeLine': ?typeLine,
        'text': ?text,
        'flavor': ?flavor,
        'power': ?power,
        'toughness': ?toughness,
        'loyalty': ?loyalty,
        'defense': ?defense,
      };

  final String name;
  final String? manaCost;
  final String? typeLine;
  final String? text;
  final String? flavor;
  final String? power;
  final String? toughness;
  final String? loyalty;
  final String? defense;
}

class MtgCardInfo extends CardInfo {
  const MtgCardInfo({
    required this.name,
    required this.manaValue,
    this.manaCost,
    this.colors = const [],
    this.colorIdentity = const [],
    this.producedMana = const [],
    this.supertypes = const [],
    this.types = const [],
    this.subtypes = const [],
    this.keywords = const [],
    this.power,
    this.toughness,
    this.loyalty,
    this.defense,
    required this.layout,
    this.faces = const [],
    required this.setCode,
    required this.collectorNumber,
  });

  factory MtgCardInfo.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) => (json[key] as List? ?? const []).cast<String>();
    return MtgCardInfo(
      name: json['name'] as String,
      manaValue: (json['manaValue'] as num).toDouble(),
      manaCost: json['manaCost'] as String?,
      colors: strings('colors'),
      colorIdentity: strings('colorIdentity'),
      producedMana: strings('producedMana'),
      supertypes: strings('supertypes'),
      types: strings('types'),
      subtypes: strings('subtypes'),
      keywords: strings('keywords'),
      power: json['power'] as String?,
      toughness: json['toughness'] as String?,
      loyalty: json['loyalty'] as String?,
      defense: json['defense'] as String?,
      layout: json['layout'] as String,
      faces: [
        for (final face in json['faces'] as List? ?? const [])
          MtgFace.fromJson(face as Map<String, dynamic>),
      ],
      setCode: json['setCode'] as String,
      collectorNumber: json['collectorNumber'] as String,
    );
  }

  /// Reads a Scryfall card object. Values a two-faced card only carries on
  /// its faces (cost, colors, type, power) come from the front face.
  factory MtgCardInfo.fromScryfall(Map<String, dynamic> json) {
    final faces = [
      for (final face in json['card_faces'] as List? ?? const [])
        MtgFace.fromScryfall(face as Map<String, dynamic>),
    ];
    final front = faces.firstOrNull;
    List<String> strings(String key) => (json[key] as List? ?? const []).cast<String>();
    final colors = json['colors'] != null
        ? strings('colors')
        : {
            for (final face in json['card_faces'] as List? ?? const [])
              ...((face as Map<String, dynamic>)['colors'] as List? ?? const []).cast<String>(),
          }.toList();
    final typeLine = front?.typeLine ?? json['type_line'] as String? ?? '';
    final (:supertypes, :types, :subtypes) = parseTypeLine(typeLine);
    return MtgCardInfo(
      name: json['printed_name'] as String? ?? json['name'] as String? ?? '',
      manaValue: (json['cmc'] as num?)?.toDouble() ?? 0,
      manaCost: json['mana_cost'] as String? ?? front?.manaCost,
      colors: colors,
      colorIdentity: strings('color_identity'),
      producedMana: strings('produced_mana'),
      supertypes: supertypes,
      types: types,
      subtypes: subtypes,
      keywords: strings('keywords'),
      power: json['power'] as String? ?? front?.power,
      toughness: json['toughness'] as String? ?? front?.toughness,
      loyalty: json['loyalty'] as String? ?? front?.loyalty,
      defense: json['defense'] as String? ?? front?.defense,
      layout: json['layout'] as String? ?? 'normal',
      faces: faces.isEmpty ? [MtgFace.fromScryfall(json)] : faces,
      setCode: (json['set'] as String? ?? '').toUpperCase(),
      collectorNumber: json['collector_number'] as String? ?? '',
    );
  }

  /// Splits `Legendary Creature — Human Samurai` into its parts.
  static ({List<String> supertypes, List<String> types, List<String> subtypes}) parseTypeLine(
      String typeLine) {
    final [left, ...right] = typeLine.split(' — ');
    final words = left.split(' ').where((w) => w.isNotEmpty).toList();
    return (
      supertypes: [for (final w in words) if (mtgSupertypes.contains(w)) w],
      types: [for (final w in words) if (!mtgSupertypes.contains(w)) w],
      subtypes: right.isEmpty ? const [] : right.join(' — ').split(' ').where((w) => w.isNotEmpty).toList(),
    );
  }

  @override
  Map<String, Object?> toJson() => {
        'game': 'mtg',
        'name': name,
        'manaValue': manaValue,
        'manaCost': ?manaCost,
        'colors': colors,
        'colorIdentity': colorIdentity,
        'producedMana': producedMana,
        'supertypes': supertypes,
        'types': types,
        'subtypes': subtypes,
        'keywords': keywords,
        'power': ?power,
        'toughness': ?toughness,
        'loyalty': ?loyalty,
        'defense': ?defense,
        'layout': layout,
        'faces': [for (final face in faces) face.toJson()],
        'setCode': setCode,
        'collectorNumber': collectorNumber,
      };

  @override
  final String name;
  final double manaValue;
  final String? manaCost;

  /// Color letters (`W`, `U`, `B`, `R`, `G`), empty for colorless.
  final List<String> colors;
  final List<String> colorIdentity;
  final List<String> producedMana;
  final List<String> supertypes;
  final List<String> types;
  final List<String> subtypes;
  final List<String> keywords;
  final String? power;
  final String? toughness;
  final String? loyalty;
  final String? defense;
  final String layout;
  final List<MtgFace> faces;
  final String setCode;
  final String collectorNumber;

  String get typeLine => [
        [...supertypes, ...types].join(' '),
        if (subtypes.isNotEmpty) subtypes.join(' '),
      ].join(' — ');

  /// Colored mana symbols in the cost, per color (devotion).
  Map<String, int> get pips {
    final counts = <String, int>{};
    for (final match in RegExp(r'\{([^}]*)\}').allMatches(manaCost ?? '')) {
      for (final color in ['W', 'U', 'B', 'R', 'G']) {
        if (match.group(1)!.contains(color)) counts.update(color, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  /// Power as a number, `null` for `*` and the like.
  int? get powerValue => int.tryParse(power ?? '');
  int? get toughnessValue => int.tryParse(toughness ?? '');
}

enum YgoKind { monster, spell, trap }

/// Monster categories YGOPRODeck lists in the card type, e.g.
/// `Pendulum Tuner Effect Monster`.
const ygoCategories = [
  'Normal', 'Effect', 'Fusion', 'Synchro', 'Xyz', 'Link', 'Pendulum', 'Ritual',
  'Tuner', 'Flip', 'Gemini', 'Spirit', 'Toon', 'Union', 'Token',
];

class YgoCardInfo extends CardInfo {
  const YgoCardInfo({
    required this.name,
    required this.kind,
    required this.type,
    this.categories = const [],
    required this.frameType,
    this.race,
    this.attribute,
    this.level,
    this.linkRating,
    this.linkMarkers = const [],
    this.scale,
    this.atk,
    this.def,
    this.archetype,
    this.text,
    this.hasEffect,
    this.setCode,
    this.setName,
  });

  factory YgoCardInfo.fromJson(Map<String, dynamic> json) => YgoCardInfo(
        name: json['name'] as String,
        kind: YgoKind.values.byName(json['kind'] as String),
        type: json['type'] as String,
        categories: (json['categories'] as List? ?? const []).cast<String>(),
        frameType: json['frameType'] as String,
        race: json['race'] as String?,
        attribute: json['attribute'] as String?,
        level: json['level'] as int?,
        linkRating: json['linkRating'] as int?,
        linkMarkers: (json['linkMarkers'] as List? ?? const []).cast<String>(),
        scale: json['scale'] as int?,
        atk: json['atk'] as int?,
        def: json['def'] as int?,
        archetype: json['archetype'] as String?,
        text: json['text'] as String?,
        hasEffect: json['hasEffect'] as bool?,
        setCode: json['setCode'] as String?,
        setName: json['setName'] as String?,
      );

  /// Reads a YGOPRODeck card object (with `misc=yes`); the set data comes
  /// from the printing matching [printCode] (any region), else the first.
  factory YgoCardInfo.fromYgoprodeck(Map<String, dynamic> json, {String? printCode}) {
    final type = json['type'] as String? ?? '';
    final kind = type.contains('Spell')
        ? YgoKind.spell
        : type.contains('Trap')
            ? YgoKind.trap
            : YgoKind.monster;
    final words = type.split(' ');
    final sets = (json['card_sets'] as List? ?? const []).cast<Map<String, dynamic>>();
    final wanted = printCode == null ? null : _printKey(printCode);
    final printing = sets.where((s) => _printKey(s['set_code'] as String? ?? '') == wanted).firstOrNull ??
        sets.firstOrNull;
    final misc = (json['misc_info'] as List? ?? const []).cast<Map<String, dynamic>>().firstOrNull;
    return YgoCardInfo(
      name: json['name'] as String? ?? '',
      kind: kind,
      type: type,
      categories: [for (final c in ygoCategories) if (words.contains(c)) c],
      frameType: json['frameType'] as String? ?? '',
      race: json['race'] as String?,
      attribute: json['attribute'] as String?,
      level: json['level'] as int?,
      linkRating: json['linkval'] as int?,
      linkMarkers: (json['linkmarkers'] as List? ?? const []).cast<String>(),
      scale: json['scale'] as int?,
      atk: json['atk'] as int?,
      def: json['def'] as int?,
      archetype: json['archetype'] as String?,
      text: json['desc'] as String?,
      hasEffect: misc == null ? null : misc['has_effect'] == 1,
      setCode: printing?['set_code'] as String?,
      setName: printing?['set_name'] as String?,
    );
  }

  /// `CIBR-FR077` and `CIBR-EN077` are the same printing: set and number.
  static String _printKey(String code) {
    final match = RegExp(r'^([A-Z0-9]+)-[A-Z]*?(\d+)$').firstMatch(code);
    return match == null ? code : '${match.group(1)}-${match.group(2)}';
  }

  @override
  Map<String, Object?> toJson() => {
        'game': 'ygo',
        'name': name,
        'kind': kind.name,
        'type': type,
        'categories': categories,
        'frameType': frameType,
        'race': ?race,
        'attribute': ?attribute,
        'level': ?level,
        'linkRating': ?linkRating,
        'linkMarkers': linkMarkers,
        'scale': ?scale,
        'atk': ?atk,
        'def': ?def,
        'archetype': ?archetype,
        'text': ?text,
        'hasEffect': ?hasEffect,
        'setCode': ?setCode,
        'setName': ?setName,
      };

  @override
  final String name;
  final YgoKind kind;

  /// YGOPRODeck's full type, e.g. `Pendulum Tuner Effect Monster`.
  final String type;
  final List<String> categories;
  final String frameType;

  /// Monster type (Warrior, Dragon…) or Spell/Trap property (Continuous…).
  final String? race;
  final String? attribute;

  /// Level, or Rank for an Xyz monster.
  final int? level;
  final int? linkRating;
  final List<String> linkMarkers;
  final int? scale;
  final int? atk;
  final int? def;
  final String? archetype;
  final String? text;
  final bool? hasEffect;
  final String? setCode;
  final String? setName;

  bool get isXyz => categories.contains('Xyz');
  bool get isLink => categories.contains('Link');
}
