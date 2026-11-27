import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../card_info/data/card_info_repository.dart';
import '../../card_info/domain/card_info.dart';
import '../../card_info/data/card_search.dart' show ygoAttributes;
import '../../card_render/generated_card.dart';
import '../../card_render/ygo_card_face.dart';
import '../../card_text/data/card_text_repository.dart';
import '../../catalog/domain/models.dart';
import '../data/pool_repository.dart';
import '../domain/card_customs.dart';
import '../domain/play_pool.dart';
import '../../packs/domain/best_versions.dart';
import 'card_field_icons.dart';
import 'card_prefill_dialog.dart';
import 'pool_actions.dart';

/// Lets the user change any field of [card] for the pool: each field shows
/// its value, flagged custom once it differs from the original, which a
/// button brings back. Answers `true` when the pool changed.
Future<bool> editCardFields(BuildContext context, {required PlayPool play, required CardData card}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 1200),
    builder: (context) => SizedBox(
      // Nearly the whole window: the drawn card is as tall as the sheet.
      height: MediaQuery.sizeOf(context).height * 0.95,
      child: CardEditSheet(play: play, card: card),
    ),
  );
  return changed ?? false;
}

/// The detail fields picked among known values rather than typed: the
/// values the pool's cards hold, plus the ones the user added for good.
const choiceFields = {
  ygoSupertypeKey,
  'attribute',
  'race',
  'archetype',
  'type',
  'frameType',
  'layout',
  'setCode',
  'setName',
};

/// The field options the user added, saved across launches per game and
/// field (`fieldOptions:ygo:attribute`).
final customFieldOptionsProvider = NotifierProvider.family<CustomFieldOptions, List<String>, (Game, String)>(
  CustomFieldOptions.new,
);

class CustomFieldOptions extends Notifier<List<String>> {
  CustomFieldOptions(this.key);

  final (Game, String) key;

  String get _prefKey => 'fieldOptions:${key.$1.name}:${key.$2}';

  @override
  List<String> build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_prefKey);
    if (saved == null) return const [];
    return (jsonDecode(saved) as List).cast<String>();
  }

  void add(String option) {
    if (state.contains(option)) return;
    state = [...state, option];
    ref.read(sharedPreferencesProvider).setString(_prefKey, jsonEncode(state));
  }
}

/// The list fields picked among known words, several at once: a Yu-Gi-Oh!
/// card's subtypes (its type with its categories: Zombie, Toon, Effect…),
/// MtG's types, supertypes, subtypes and keywords, One Piece's subtypes;
/// the known words come from the pool's cards and the user.
const multiChoiceFields = {
  'subtypes': ygoCategories,
  'types': <String>[],
  'supertypes': <String>[],
  'keywords': <String>[],
};

/// The fields told from others rather than edited: a Yu-Gi-Oh! card's
/// type, categories, frame and type string all follow its subtypes.
const derivedFields = {'race', 'categories', 'frameType', 'type'};

/// The fields the editor keeps as they are, without a line of their own:
/// the rarities and whether the card has an effect.
const hiddenFields = {'${cardFieldPrefix}rarity', '${cardFieldPrefix}printedRarity', 'hasEffect'};

/// The virtual field standing for a Yu-Gi-Oh! card's type and categories.
const ygoSubtypesKey = 'subtypes';

/// Whether [key] applies to a [game]'s cards at all: MtG alone colors its
/// cards by letters on the card itself.
/// The field keys in the order a card shows them, top to bottom: name,
/// cost, attribute, level, type line, text, stats, then what is printed
/// small or not at all (rarity, archetype, set). Keys the order does not
/// know come last, as they were.
List<String> orderedFieldKeys(Iterable<String> keys) {
  const order = [
    ygoSupertypeKey,
    'manaCost',
    'manaValue',
    'cost',
    'attribute',
    'level',
    'linkRating',
    'linkMarkers',
    'scale',
    'life',
    '${cardFieldPrefix}colors',
    'colors',
    'colorIdentity',
    'supertypes',
    'types',
    'type',
    'race',
    ygoSubtypesKey,
    'categories',
    'frameType',
    'typeLine',
    'text',
    'flavor',
    'power',
    'counter',
    'atk',
    'toughness',
    'def',
    'defense',
    'loyalty',
    'keywords',
    'producedMana',
    '${cardFieldPrefix}rarity',
    '${cardFieldPrefix}printedRarity',
    'archetype',
    'layout',
    'hasEffect',
    'setCode',
    'setName',
    'collectorNumber',
  ];
  int rank(String key) {
    // Names first, whatever their language.
    if (key.startsWith('${cardFieldPrefix}name')) return -1;
    final at = order.indexOf(key);
    return at < 0 ? order.length : at;
  }

  final list = keys.toList();
  final place = {for (final (i, key) in list.indexed) key: i};
  return list..sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : place[a]! - place[b]!);
}

bool fieldAppliesTo(String key, Game game) => key != '${cardFieldPrefix}colors' || game == Game.mtg;

class CardEditSheet extends ConsumerStatefulWidget {
  const CardEditSheet({super.key, required this.play, required this.card});

  final PlayPool play;
  final CardData card;

  @override
  ConsumerState<CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends ConsumerState<CardEditSheet> {
  /// What each field reads now, by key.
  final _controllers = <String, TextEditingController>{};
  final _focuses = <String, FocusNode>{};

  /// The word being typed into each multiple-choice field, apart from the
  /// field's value (the words picked so far).
  final _adders = <String, TextEditingController>{};

  /// The rarity fields, picked rather than typed.
  late String _rarity;
  late String? _printedRarity;

  /// The original values, by key: what a custom field reverts to.
  late final Map<String, Object?> _bases;

  /// The card's original details, `null` when none were downloaded.
  CardInfo? _baseInfo;

  /// The field keys in order: the card's, then its details'.
  late final List<String> _keys;

  /// The values the pool's cards hold per choice field, as options.
  late final Map<String, Set<String>> _poolOptions;

  /// The other printings of the card in the pool that have details, two
  /// reading the same kept once: what a field may be prefilled from.
  late final List<CardVersion> _versions;

  String get _id => widget.card.id;
  Game get _game => widget.play.pool.game;
  CardCustoms get _customs => widget.play.pool.customsOf(_id);

  @override
  void initState() {
    super.initState();
    final base = widget.play.bases[_id] ?? widget.card;
    final infos = ref.read(poolCardInfoProvider(widget.play.pool.id)).value?.infos ?? const {};
    final baseInfo = infos[_id];
    _baseInfo = baseInfo;
    _bases = {
      // The names are not edited here: a card keeps its own.
      for (final key in cardFieldKeys(base))
        if (fieldAppliesTo(key, _game) && !key.startsWith('${cardFieldPrefix}name')) key: cardFieldValue(base, key),
      if (baseInfo != null) ...editableInfoFields(baseInfo),
    };
    // A Yu-Gi-Oh! monster has one tribe, a field of its own, and its
    // categories edit as one subtypes field; a spell or a trap only has
    // its kind, where a monster has its tribe.
    if (baseInfo is YgoCardInfo && baseInfo.kind == YgoKind.monster) {
      _bases[ygoSubtypesKey] = ygoSubtypes(categories: baseInfo.categories);
    }
    _keys = orderedFieldKeys(_bases.keys);
    _poolOptions = {
      for (final key in _keys)
        if (_isChoice(key) || _isMultiChoice(key))
          key: {
            for (final info in infos.values)
              if (editableInfoFields(info)[key] case final value?)
                if (value is String && value.isNotEmpty) value else if (value is List) ...value.cast<String>(),
          },
    };
    final current = {..._bases, ..._customs};
    for (final key in _keys) {
      if (key == '${cardFieldPrefix}rarity' || key == '${cardFieldPrefix}printedRarity') continue;
      _controllers[key] = TextEditingController(text: fieldText(current[key]));
      // Every field can take the focus: a click on the drawn card sends it.
      _focuses[key] = FocusNode();
      if (_isMultiChoice(key)) _adders[key] = TextEditingController();
    }
    _rarity = '${current['${cardFieldPrefix}rarity']}';
    _printedRarity = current['${cardFieldPrefix}printedRarity'] as String?;
    _versions = _otherVersions(infos);
  }

  /// The other printings of the card (same base id) with details, as the
  /// editor reads their fields; two that read the same are one.
  List<CardVersion> _otherVersions(Map<String, CardInfo> infos) {
    final baseId = baseCardId(_id);
    final seen = <String>{};
    final versions = <CardVersion>[];
    for (final (:card, listed: _) in widget.play.entries) {
      if (card.id == _id || baseCardId(card.id) != baseId) continue;
      final info = infos[card.id];
      if (info == null) continue;
      final fields = {
        for (final MapEntry(:key, :value) in editableInfoFields(info).entries) key: fieldText(value),
        if (info is YgoCardInfo && info.kind == YgoKind.monster)
          ygoSubtypesKey: fieldText(ygoSubtypes(categories: info.categories)),
      };
      final edited = {
        for (final key in _keys)
          if (fields.containsKey(key)) key: fields[key]!,
      };
      if (!seen.add(edited.entries.map((e) => '${e.key}=${e.value}').join('\u0000'))) continue;
      final suffix = card.id.length > baseId.length ? card.id.substring(baseId.length + 1) : card.id;
      final rarity = card.printed.name;
      versions.add((id: card.id, label: '$suffix · $rarity', fields: edited));
    }
    return versions;
  }

  /// Whether some other printing reads [key] otherwise than this card now.
  bool _hasPrefill(String key) => _versions.any((v) => (v.fields[key] ?? '') != fieldText(_valueOf(key)));

  /// Takes fields from another printing: every field, or [field] alone,
  /// each change shown before it is made.
  Future<void> _prefill({String? field}) async {
    final keys = [
      for (final key in _keys)
        if (_controllers.containsKey(key) && !_isDerived(key) && !hiddenFields.contains(key)) key,
    ];
    final picked = await showPrefillDialog(
      context,
      versions: _versions,
      current: {for (final key in keys) key: fieldText(_valueOf(key))},
      keys: keys,
      label: _label,
      field: field,
    );
    if (picked == null || !mounted) return;
    setState(() {
      for (final MapEntry(:key, :value) in picked.entries) {
        _controllers[key]?.text = value;
        if (_isMultiChoice(key)) _refreshOptions(key);
      }
    });
  }

  @override
  void dispose() {
    for (final c in [..._controllers.values, ..._adders.values]) {
      c.dispose();
    }
    for (final f in _focuses.values) {
      f.dispose();
    }
    super.dispose();
  }

  bool _isChoice(String key) => choiceFields.contains(key) && _bases[key] is String?;

  bool _isMultiChoice(String key) => multiChoiceFields.containsKey(key) && _bases[key] is List;

  /// Whether [key] reads something else than its original.
  bool _isCustom(String key) => fieldText(_valueOf(key)) != fieldText(_bases[key]);

  Object? _valueOf(String key) {
    if (key == '${cardFieldPrefix}rarity') return _rarity;
    if (key == '${cardFieldPrefix}printedRarity') return _printedRarity;
    if (_game == Game.ygo && _controllers.containsKey(ygoSubtypesKey) && _isDerived(key)) {
      // The categories, frame and type string follow the subtypes: the
      // known ones in their usual order, then the words of one's own.
      final picked = _picked(ygoSubtypesKey);
      final categories = [
        for (final c in ygoCategoryOrder)
          if (picked.contains(c)) c,
        for (final w in picked)
          if (!ygoCategoryOrder.contains(w)) w,
      ];
      return switch (key) {
        'categories' => categories,
        'frameType' => ygoFrameFromCategories(categories) ?? _bases[key],
        _ => ygoTypeString(categories, '${_bases[key] ?? ''}'),
      };
    }
    return parseFieldText(_controllers[key]!.text, _bases[key]);
  }

  /// The fields told from the subtypes rather than edited; the tribe (or a
  /// spell's kind) is a field of its own.
  bool _isDerived(String key) => _game == Game.ygo && derivedFields.contains(key) && key != 'race';

  /// The type line the card reads with, from the fields as they are.
  /// The Yu-Gi-Oh! details as the fields make them now, to draw the card
  /// as it will be; `null` for another game, a card without details, or
  /// values that make no card (a level that is no number).
  YgoCardInfo? get _drawnInfo {
    final base = _baseInfo;
    if (base is! YgoCardInfo) return null;
    final json = base.toJson();
    for (final key in _keys) {
      if (key.startsWith(cardFieldPrefix) || key == ygoSubtypesKey) continue;
      final value = _valueOf(key);
      value == null ? json.remove(key) : json[key] = value;
    }
    try {
      final info = CardInfo.fromJson(json);
      return info is YgoCardInfo ? info : null;
    } on Object {
      return null;
    }
  }

  /// A click on a part of the drawn card: the level is picked in a dialog,
  /// the other parts send the focus to their field (the name is not edited).
  Future<void> _editPart(YgoCardPart part) async {
    switch (part) {
      case YgoCardPart.attribute:
        _focusField('attribute');
      case YgoCardPart.level:
        await _pickLevel();
      case YgoCardPart.name:
        break;
      case YgoCardPart.type:
        _focusField('race');
      case YgoCardPart.text:
        _focusField('text');
      case YgoCardPart.atk:
        _focusField('atk');
      case YgoCardPart.def:
        _focusField('def');
      case YgoCardPart.link:
        _focusField('linkRating');
    }
  }

  /// Sends the focus to the field of [key], which scrolls it into view.
  void _focusField(String key) => _focuses[key]?.requestFocus();

  /// Picks the level (or rank) from none to twelve.
  Future<void> _pickLevel() async {
    final controller = _controllers['level'];
    if (controller == null) return;
    final current = int.tryParse(controller.text.trim()) ?? 0;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('pickLevel'),
        title: Text(_label('level')),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var level = 0; level <= 12; level++)
                ChoiceChip(
                  key: ValueKey('level-$level'),
                  label: Text(level == 0 ? '—' : '$level'),
                  selected: level == current,
                  showCheckmark: false,
                  onSelected: (_) => Navigator.pop(context, level),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => controller.text = picked == 0 ? '' : '$picked');
  }

  String get _typeLine => computedTypeLine(_game, {for (final key in _keys) key: _valueOf(key)});

  /// The words picked in a multiple-choice field.
  List<String> _picked(String key) => [
    for (final w in _controllers[key]!.text.split(','))
      if (w.trim().isNotEmpty) w.trim(),
  ];

  void _setPicked(String key, List<String> words) {
    setState(() => _controllers[key]!.text = words.join(', '));
    // The list of words still to pick only follows what is typed: tell it
    // the picked ones changed, so a word taken out is offered again at once.
    _refreshOptions(key);
  }

  /// Has the list of words still to pick of [key] worked out again, and
  /// shown when its field has the focus: it only follows what is typed.
  void _refreshOptions(String key) {
    if (_adders[key] case final adder?) {
      final typed = adder.value;
      adder.value = typed.copyWith(text: '${typed.text} ');
      adder.value = typed;
    }
  }

  /// Whether the card is a Yu-Gi-Oh! monster (or not known to be a spell
  /// or a trap), as its supertype field reads now: its subtypes are a
  /// tribe and categories.
  bool get _ygoMonster => switch (_controllers[ygoSupertypeKey]?.text) {
    final String typed when typed.trim().isNotEmpty => YgoKind.fromLabel(typed) == YgoKind.monster,
    _ => _baseInfo is! YgoCardInfo || (_baseInfo as YgoCardInfo).kind == YgoKind.monster,
  };

  bool _isYgoSubtypes(String key) => _game == Game.ygo && key == ygoSubtypesKey;

  /// Adds [word] to the words picked for [key]. A Yu-Gi-Oh! monster's
  /// subtypes stay in printed order (Synchro, Pendulum, Tuner, Effect),
  /// words of one's own last.
  void _addPicked(String key, String word) {
    final words = [..._picked(key), word];
    _setPicked(
      key,
      _isYgoSubtypes(key)
          ? [
              for (final c in ygoPrintOrder)
                if (words.contains(c)) c,
              for (final w in words)
                if (!ygoPrintOrder.contains(w)) w,
            ]
          : words,
    );
  }

  void _revert(String key) => setState(() {
    if (key == '${cardFieldPrefix}rarity') {
      _rarity = '${_bases[key]}';
    } else if (key == '${cardFieldPrefix}printedRarity') {
      _printedRarity = _bases[key] as String?;
    } else {
      _controllers[key]!.text = fieldText(_bases[key]);
    }
  });

  Future<void> _apply() async {
    var pool = widget.play.pool;
    for (final key in _keys) {
      // The subtypes field is the editor's own: its parts are what is kept.
      if (key == ygoSubtypesKey && _game == Game.ygo) continue;
      final custom = _isCustom(key);
      pool = pool.withCustom(_id, key, custom ? _valueOf(key) : null, remove: !custom);
    }
    if (pool.customs != widget.play.pool.customs) {
      await ref.read(poolsProvider.notifier).save(pool);
    }
    if (mounted) Navigator.pop(context, true);
  }

  /// Every option of a choice field: the pool's values and the user's, sorted.
  List<String> _options(String key) {
    final added = ref.watch(customFieldOptionsProvider((_game, key)));
    final base = _bases[key];
    return {
      // Every tribe of the game for a Yu-Gi-Oh! monster, every kind for a
      // spell or a trap, whatever the pool's cards hold.
      if (_game == Game.ygo && key == 'race') ...(_ygoMonster ? ygoMonsterTypes : ygoSpellTrapKinds),
      // Every attribute and supertype of the game.
      if (_game == Game.ygo && key == 'attribute') ...ygoAttributes,
      if (key == ygoSupertypeKey) ...ygoSupertypes,
      ...?_poolOptions[key],
      if (base is String && base.isNotEmpty) base,
      ...added,
    }.toList()..sort();
  }

  /// Asks for a new option of [key], kept for good, and picks it.
  Future<void> _addOption(String key) async {
    final l10n = AppLocalizations.of(context);
    final option = await askName(context, l10n.customOptionTitle(_label(key)), label: _label(key));
    if (option == null || !mounted) return;
    ref.read(customFieldOptionsProvider((_game, key)).notifier).add(option);
    setState(() => _controllers[key]!.text = option);
  }

  /// A field's name as the user reads it: `manaCost` as "Mana cost",
  /// `card.name.fr` as "Name (fr)".
  String _label(String key) {
    // A Yu-Gi-Oh! monster's type is its tribe, a spell's or a trap's its kind.
    if (_game == Game.ygo && key == 'race') {
      final l10n = AppLocalizations.of(context);
      return _ygoMonster ? l10n.fieldTribe : l10n.fieldSpellKind;
    }
    if (key == ygoSupertypeKey) return AppLocalizations.of(context).fieldSupertype;
    var name = key.startsWith(cardFieldPrefix) ? key.substring(cardFieldPrefix.length) : key;
    String? suffix;
    if (name.startsWith('name.')) {
      suffix = name.substring(5);
      name = 'name';
    }
    final words = name.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]!.toLowerCase()}');
    final label = words[0].toUpperCase() + words.substring(1);
    return suffix == null ? label : '$label ($suffix)';
  }

  /// The marker of a custom option in the choice lists.
  static const _customOption = '\u0000custom';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // What leads a field on its line: its icon and name, then the custom
    // flag and the way back to the original.
    List<Widget> leading(String key, {double nameWidth = 150}) {
      final custom = _isCustom(key);
      final base = fieldText(_bases[key]);
      final prefill = _controllers.containsKey(key) && _hasPrefill(key);
      return [
        SizedBox(
          width: nameWidth,
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: switch (fieldIcon(key)) {
                  null => null,
                  final icon => Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                },
              ),
              Expanded(child: Text(_label(key), style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
        // The slot of the prefill button, only when there are versions.
        if (_versions.isNotEmpty)
          SizedBox(
            width: 24,
            child: prefill
                ? IconButton(
                    key: ValueKey('prefill-$key'),
                    tooltip: l10n.prefillField,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () => _prefill(field: key),
                  )
                : null,
          ),
        // The custom flag and the way back, right of the name.
        SizedBox(
          width: 24,
          child: custom
              ? Icon(Icons.brush, key: ValueKey('custom-$key'), size: 18, color: theme.colorScheme.primary)
              : null,
        ),
        SizedBox(
          width: 32,
          child: custom
              ? IconButton(
                  key: ValueKey('revert-$key'),
                  tooltip: l10n.revertField(base.isEmpty ? l10n.fieldEmpty : base),
                  icon: const Icon(Icons.restart_alt, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => _revert(key),
                )
              : null,
        ),
        const SizedBox(width: 8),
      ];
    }

    Widget row(String key, Widget field) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ...leading(key),
          Expanded(child: field),
        ],
      ),
    );

    // A field typed as plain text.
    Widget textField(String key) => TextField(
      key: ValueKey('field-$key'),
      controller: _controllers[key],
      focusNode: _focuses[key],
      maxLines: key == 'text' ? null : 1,
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      onChanged: (_) => setState(() {}),
    );

    // A multiple-choice field: the picked words as chips, one more typed
    // with the known words offered as one types.
    Widget multiChoiceField(String key) {
      final picked = _picked(key);
      final options = [
        for (final option in {
          ...multiChoiceFields[key]!,
          ...?_poolOptions[key],
          ...ref.watch(customFieldOptionsProvider((_game, key))),
        })
          option,
      ]..sort();
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final word in picked)
            InputChip(
              key: ValueKey('pick-$key-$word'),
              avatar: valueIconWidget(_game, key, word, size: 18),
              label: Text(word),
              visualDensity: VisualDensity.compact,
              onDeleted: () => _setPicked(key, [
                for (final w in picked)
                  if (w != word) w,
              ]),
            ),
          SizedBox(
            width: 200,
            child: RawAutocomplete<String>(
              // A focus node comes with its controller, or with neither.
              textEditingController: _adders[key],
              focusNode: _focuses[key],
              optionsBuilder: (value) {
                // The words picked as they are now, not as they were when
                // this list was last built.
                final now = _picked(key);
                final query = value.text.trim().toLowerCase();
                return [
                  for (final option in options)
                    if (!now.contains(option) && option.toLowerCase().contains(query)) option,
                ];
              },
              onSelected: (option) {
                // The picked word becomes a chip: the field is free again.
                _adders[key]?.clear();
                _addPicked(key, option);
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                key: ValueKey('field-$key'),
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), hintText: l10n.addWord),
                // A click on the field shows the words again, also when
                // it already had the focus.
                onTap: () => _refreshOptions(key),
                onSubmitted: (text) {
                  // A word of one's own is kept among the known ones.
                  final word = text.trim();
                  if (word.isNotEmpty && !picked.contains(word)) {
                    ref.read(customFieldOptionsProvider((_game, key)).notifier).add(word);
                    _addPicked(key, word);
                  }
                  controller.clear();
                },
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240, maxWidth: 240),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final option in options)
                          ListTile(
                            dense: true,
                            leading: ValueIcon(_game, key, option, size: 22),
                            title: Text(option),
                            onTap: () => onSelected(option),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // A choice field: the known values filtered as one types, then "Custom…".
    Widget choiceField(String key) {
      final options = _options(key);
      return RawAutocomplete<String>(
        textEditingController: _controllers[key],
        focusNode: _focuses[key],
        optionsBuilder: (value) {
          final query = value.text.toLowerCase();
          return [
            for (final option in options)
              if (option.toLowerCase().contains(query)) option,
            _customOption,
          ];
        },
        displayStringForOption: (option) => option == _customOption ? l10n.customOption : option,
        onSelected: (option) {
          if (option == _customOption) {
            _controllers[key]!.text = fieldText(_valueOf(key));
            _addOption(key);
          } else {
            setState(() {});
          }
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
          key: ValueKey('field-$key'),
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            prefixIcon: switch (valueIconWidget(
              _game,
              key,
              controller.text,
              size: 22,
              key: ValueKey('valueIcon-$key'),
            )) {
              null => null,
              // Its own size, not stretched to the field's height.
              final icon => Padding(padding: const EdgeInsets.all(8), child: icon),
            },
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => onSubmitted(),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      key: option == _customOption ? ValueKey('customOption-$key') : null,
                      dense: true,
                      leading: option == _customOption
                          ? const Icon(Icons.add, size: 18)
                          : ValueIcon(_game, key, option, size: 22),
                      title: Text(option == _customOption ? l10n.customOption : option),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(l10n.editCard, style: theme.textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.editCardHint, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              // The last of the fields a type line is made of: it reads under it.
              final typeLineAfter = _keys
                  .where((k) => const {'supertypes', 'types', 'type', 'subtypes'}.contains(k) && !_isDerived(k))
                  .lastOrNull;
              // Every row is built, so any field can be focused from the card.
              final fields = SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_versions.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('prefillCard'),
                          onPressed: _prefill,
                          icon: const Icon(Icons.file_download_outlined, size: 18),
                          label: Text(l10n.prefillFromVersion),
                        ),
                      ),
                    for (final key in _keys) ...[
                      // Not edited here: what follows other fields, the rarities
                      // (a matter of the pool's tags) and whether the card has
                      // an effect (its subtypes say it). DEF sits on ATK's line.
                      if (_isDerived(key) || hiddenFields.contains(key) || (key == 'def' && _keys.contains('atk')))
                        const SizedBox.shrink()
                      else if (_isMultiChoice(key))
                        row(key, multiChoiceField(key))
                      else if (key == 'atk' && _keys.contains('def'))
                        Padding(
                          key: const Key('statsRow'),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              ...leading('atk'),
                              Expanded(child: textField('atk')),
                              const SizedBox(width: 16),
                              ...leading('def', nameWidth: 70),
                              Expanded(child: textField('def')),
                            ],
                          ),
                        )
                      else if (_isChoice(key))
                        row(key, choiceField(key))
                      else
                        row(key, textField(key)),
                      // The type line as those fields make it, live, under them.
                      if (key == typeLineAfter)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 150,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 26),
                                    Expanded(child: Text(l10n.typeLine, style: theme.textTheme.bodySmall)),
                                  ],
                                ),
                              ),
                              // As wide as a row's prefill, custom flag and revert buttons.
                              SizedBox(width: _versions.isEmpty ? 64 : 88),
                              Expanded(
                                child: Text(_typeLine, key: const Key('typeLine'), style: theme.textTheme.titleSmall),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              );
              return fields;
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
              const SizedBox(width: 8),
              FilledButton(key: const Key('applyCardEdit'), onPressed: _apply, child: Text(l10n.apply)),
            ],
          ),
        ),
      ],
    );

    // The card as its fields make it, beside them when there is room: as
    // tall as the sheet, as long as the fields keep enough width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final drawn = constraints.maxWidth >= 760 ? _drawnInfo : null;
        if (drawn == null) return form;
        const ratio = YgoCardFace.width / YgoCardFace.height;
        const hint = 30.0;
        final height = constraints.maxHeight - 16;
        final width = ((height - hint) * ratio).clamp(160.0, constraints.maxWidth - 16 - 480);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 0, 16),
              child: SizedBox(
                width: width,
                height: height,
                child: Column(
                  children: [
                    Flexible(
                      child: AspectRatio(
                        aspectRatio: ratio,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(width / 22),
                          child: GeneratedYgoCard(
                            key: const Key('editDrawnCard'),
                            card: widget.card,
                            info: drawn,
                            name: widget.card.nameFor(dataLanguage(ref, context)),
                            onPart: _editPart,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.editOnCardHint,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: form),
          ],
        );
      },
    );
  }
}
