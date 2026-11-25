import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../card_info/data/card_info_repository.dart';
import '../../catalog/domain/models.dart';
import '../data/pool_repository.dart';
import '../domain/card_customs.dart';
import '../domain/play_pool.dart';

/// Lets the user change any field of [card] for the pool: each field shows
/// its value, flagged custom once it differs from the original, which a
/// button brings back. Answers `true` when the pool changed.
Future<bool> editCardFields(BuildContext context, {required PlayPool play, required CardData card}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: CardEditSheet(play: play, card: card),
    ),
  );
  return changed ?? false;
}

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

  /// The rarity fields, picked rather than typed.
  late String _rarity;
  late String? _printedRarity;

  /// The original values, by key: what a custom field reverts to.
  late final Map<String, Object?> _bases;

  /// The field keys in order: the card's, then its details'.
  late final List<String> _keys;

  String get _id => widget.card.id;
  CardCustoms get _customs => widget.play.pool.customsOf(_id);

  @override
  void initState() {
    super.initState();
    final base = widget.play.bases[_id] ?? widget.card;
    final baseInfo = ref.read(poolCardInfoProvider(widget.play.pool.id)).value?.infos[_id];
    _bases = {
      for (final key in cardFieldKeys(base)) key: cardFieldValue(base, key),
      if (baseInfo != null) ...editableInfoFields(baseInfo),
    };
    _keys = _bases.keys.toList();
    final current = {..._bases, ..._customs};
    for (final key in _keys) {
      if (key == '${cardFieldPrefix}rarity' || key == '${cardFieldPrefix}printedRarity') continue;
      _controllers[key] = TextEditingController(text: fieldText(current[key]));
    }
    _rarity = '${current['${cardFieldPrefix}rarity']}';
    _printedRarity = current['${cardFieldPrefix}printedRarity'] as String?;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Whether [key] reads something else than its original.
  bool _isCustom(String key) {
    final value = _valueOf(key);
    return fieldText(value) != fieldText(_bases[key]);
  }

  Object? _valueOf(String key) {
    if (key == '${cardFieldPrefix}rarity') return _rarity;
    if (key == '${cardFieldPrefix}printedRarity') return _printedRarity;
    return parseFieldText(_controllers[key]!.text, _bases[key]);
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
      final custom = _isCustom(key);
      pool = pool.withCustom(_id, key, custom ? _valueOf(key) : null, remove: !custom);
    }
    if (pool.customs != widget.play.pool.customs) {
      await ref.read(poolsProvider.notifier).save(pool);
    }
    if (mounted) Navigator.pop(context, true);
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 140, child: Text(_label(key), style: theme.textTheme.bodyMedium)),
            Expanded(child: field),
            SizedBox(
              width: 150,
              child: custom
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          key: ValueKey('custom-$key'),
                          label: Text(l10n.customField),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          key: ValueKey('revert-$key'),
                          tooltip: l10n.revertField(base.isEmpty ? l10n.fieldEmpty : base),
                          icon: const Icon(Icons.restart_alt),
                          onPressed: () => _revert(key),
                        ),
                      ],
                    )
                  : null,
            ),
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
                if (key == '${cardFieldPrefix}rarity')
                  row(key, rarityField(key, _rarity, nullable: false))
                else if (key == '${cardFieldPrefix}printedRarity')
                  row(key, rarityField(key, _printedRarity, nullable: true))
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
