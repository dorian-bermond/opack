import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../card_info/data/card_info_repository.dart';
import '../../card_info/domain/card_info.dart';
import '../../card_text/data/card_text_repository.dart';
import '../../catalog/domain/models.dart';
import '../data/pool_repository.dart';
import '../domain/card_customs.dart';
import '../domain/play_pool.dart';
import 'pool_actions.dart';

/// Lets the user change any field of [card] for the pool: each field shows
/// its value, flagged custom once it differs from the original, which a
/// button brings back. Answers `true` when the pool changed.
Future<bool> editCardFields(BuildContext context, {required PlayPool play, required CardData card}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 1100),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: CardEditSheet(play: play, card: card),
    ),
  );
  return changed ?? false;
}

/// The detail fields picked among known values rather than typed: the
/// values the pool's cards hold, plus the ones the user added for good.
const choiceFields = {'attribute', 'race', 'archetype', 'type', 'frameType', 'layout', 'setCode', 'setName'};

/// The field options the user added, saved across launches per game and
/// field (`fieldOptions:ygo:attribute`).
final customFieldOptionsProvider =
    NotifierProvider.family<CustomFieldOptions, List<String>, (Game, String)>(CustomFieldOptions.new);

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
/// card's categories (Effect, Tuner, Pendulum…).
const multiChoiceFields = {'categories': ygoCategories};

/// The fields told from others rather than edited: a Yu-Gi-Oh! frame
/// follows the categories.
const derivedFields = {'frameType'};

/// Whether [key] applies to a [game]'s cards at all: MtG alone colors its
/// cards by letters on the card itself.
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

  /// The rarity fields, picked rather than typed.
  late String _rarity;
  late String? _printedRarity;

  /// The original values, by key: what a custom field reverts to.
  late final Map<String, Object?> _bases;

  /// The field keys in order: the card's, then its details'.
  late final List<String> _keys;

  /// The values the pool's cards hold per choice field, as options.
  late final Map<String, Set<String>> _poolOptions;

  String get _id => widget.card.id;
  Game get _game => widget.play.pool.game;
  CardCustoms get _customs => widget.play.pool.customsOf(_id);

  @override
  void initState() {
    super.initState();
    final base = widget.play.bases[_id] ?? widget.card;
    final infos = ref.read(poolCardInfoProvider(widget.play.pool.id)).value?.infos ?? const {};
    final baseInfo = infos[_id];
    _bases = {
      for (final key in cardFieldKeys(base))
        if (fieldAppliesTo(key, _game)) key: cardFieldValue(base, key),
      if (baseInfo != null) ...editableInfoFields(baseInfo),
    };
    _keys = _bases.keys.toList();
    _poolOptions = {
      for (final key in _keys)
        if (_isChoice(key) || multiChoiceFields.containsKey(key))
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
      if (_isChoice(key) || multiChoiceFields.containsKey(key)) _focuses[key] = FocusNode();
    }
    _rarity = '${current['${cardFieldPrefix}rarity']}';
    _printedRarity = current['${cardFieldPrefix}printedRarity'] as String?;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focuses.values) {
      f.dispose();
    }
    super.dispose();
  }

  bool _isChoice(String key) => choiceFields.contains(key) && _bases[key] is String?;

  /// Whether [key] reads something else than its original.
  bool _isCustom(String key) => fieldText(_valueOf(key)) != fieldText(_bases[key]);

  Object? _valueOf(String key) {
    if (key == '${cardFieldPrefix}rarity') return _rarity;
    if (key == '${cardFieldPrefix}printedRarity') return _printedRarity;
    if (key == 'frameType' && _game == Game.ygo && _controllers.containsKey('categories')) {
      // The frame follows the categories: Fusion and Pendulum make a fusion pendulum.
      return ygoFrameFromCategories(_picked('categories')) ?? _bases[key];
    }
    return parseFieldText(_controllers[key]!.text, _bases[key]);
  }

  /// The words picked in a multiple-choice field.
  List<String> _picked(String key) =>
      [for (final w in _controllers[key]!.text.split(',')) if (w.trim().isNotEmpty) w.trim()];

  void _setPicked(String key, List<String> words) => setState(() => _controllers[key]!.text = words.join(', '));

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
    return {...?_poolOptions[key], if (base is String && base.isNotEmpty) base, ...added}.toList()..sort();
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

    Widget row(String key, Widget field) {
      final custom = _isCustom(key);
      final base = fieldText(_bases[key]);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 150, child: Text(_label(key), style: theme.textTheme.bodyMedium)),
            // The custom flag and the way back, right of the name.
            SizedBox(
              width: 32,
              child: custom
                  ? Icon(Icons.brush, key: ValueKey('custom-$key'), size: 18, color: theme.colorScheme.primary)
                  : null,
            ),
            SizedBox(
              width: 40,
              child: custom
                  ? IconButton(
                      key: ValueKey('revert-$key'),
                      tooltip: l10n.revertField(base.isEmpty ? l10n.fieldEmpty : base),
                      icon: const Icon(Icons.restart_alt, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _revert(key),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(child: field),
          ],
        ),
      );
    }

    Widget rarityField(String key, String? value, {required bool nullable}) => DropdownButton<String?>(
          key: ValueKey('field-$key'),
          isExpanded: true,
          value: value,
          items: [
            if (nullable) DropdownMenuItem(value: null, child: Text(l10n.fieldEmpty)),
            for (final rarity in Rarity.values) DropdownMenuItem(value: rarity.name, child: Text(rarity.label(l10n))),
          ],
          onChanged: (v) => setState(() {
            if (nullable) {
              _printedRarity = v;
            } else if (v != null) {
              _rarity = v;
            }
          }),
        );

    // A multiple-choice field: the picked words as chips, one more typed
    // with the known words offered as one types.
    Widget multiChoiceField(String key) {
      final picked = _picked(key);
      final options = [
        for (final option in {...multiChoiceFields[key]!, ...?_poolOptions[key]})
          if (!picked.contains(option)) option,
      ];
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final word in picked)
            InputChip(
              key: ValueKey('pick-$key-$word'),
              label: Text(word),
              visualDensity: VisualDensity.compact,
              onDeleted: () => _setPicked(key, [for (final w in picked) if (w != word) w]),
            ),
          SizedBox(
            width: 200,
            child: RawAutocomplete<String>(
              focusNode: _focuses[key],
              optionsBuilder: (value) {
                final query = value.text.toLowerCase();
                return [for (final option in options) if (option.toLowerCase().contains(query)) option];
              },
              onSelected: (option) => _setPicked(key, [...picked, option]),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                key: ValueKey('field-$key'),
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: l10n.addWord,
                ),
                onSubmitted: (text) {
                  final word = text.trim();
                  if (word.isNotEmpty && !picked.contains(word)) _setPicked(key, [...picked, word]);
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
                          ListTile(dense: true, title: Text(option), onTap: () => onSelected(option)),
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
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.arrow_drop_down),
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
                      leading: option == _customOption ? const Icon(Icons.add, size: 18) : null,
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

    return Column(
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final key in _keys)
                if (derivedFields.contains(key))
                  const SizedBox.shrink()
                else if (multiChoiceFields.containsKey(key))
                  row(key, multiChoiceField(key))
                else if (key == '${cardFieldPrefix}rarity')
                  row(key, rarityField(key, _rarity, nullable: false))
                else if (key == '${cardFieldPrefix}printedRarity')
                  row(key, rarityField(key, _printedRarity, nullable: true))
                else if (_isChoice(key))
                  row(key, choiceField(key))
                else
                  row(
                    key,
                    TextField(
                      key: ValueKey('field-$key'),
                      controller: _controllers[key],
                      maxLines: key == 'text' ? null : 1,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
            ],
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
  }
}
