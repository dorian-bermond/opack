import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../card_info/presentation/labels.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../cube/data/cube_repository.dart';
import '../data/pool_repository.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_composition_screen.dart';
import 'pool_widgets.dart';
import 'source_picker.dart';

/// Actions on a pool shared by its details page and its editor.

void savePool(WidgetRef ref, Pool pool) => ref.read(poolsProvider.notifier).save(pool);

/// Asks for a name; `null` when dismissed or left blank.
Future<String?> askName(BuildContext context, String title, {String initial = '', String? label}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: title, initial: initial, label: label),
  );
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

Future<void> renamePool(BuildContext context, WidgetRef ref, Pool pool) async {
  final name = await askName(context, AppLocalizations.of(context).renamePool, initial: pool.name);
  if (name != null) savePool(ref, pool.copyWith(name: name));
}

/// Adds a set or a cube; its cards join the tags the pool already has
/// (rarities, all cards, and the set's own sheet names).
Future<void> addPoolSource(BuildContext context, WidgetRef ref, PlayPool play) async {
  final pool = play.pool;
  final source = await pickPoolSource(context, game: pool.game, exclude: pool.sources);
  if (source == null) return;
  final existing = play.entries.map((e) => e.card);
  switch (source) {
    case SetSource(:final code):
      final set = await ref.read(catalogRepositoryProvider).loadSet(pool.game, code);
      savePool(ref, pool.withSource(source, cards: set.cards, existing: existing, set: set));
    case CubeSource(:final id):
      final cube = (await ref.read(cubesProvider.future)).where((c) => c.id == id).firstOrNull;
      savePool(ref, pool.withSource(source, cards: cube?.cards ?? const [], existing: existing));
    case CardsSource(:final cards):
      savePool(ref, pool.withSource(source, cards: cards, existing: existing));
  }
}

/// Creates an empty plain tag (a yes/no trait) and answers its name;
/// `null` when dismissed or already taken.
Future<String?> newPoolTag(BuildContext context, WidgetRef ref, Pool pool) async {
  final l10n = AppLocalizations.of(context);
  final name = await askName(context, l10n.newTag, label: l10n.tagName);
  if (name == null) return null;
  final clean = name.replaceAll(':', '');
  if (clean.isEmpty || pool.tags.containsKey(clean)) return null;
  savePool(ref, pool.withTag(clean, const []));
  return clean;
}

/// Creates a value of [quality], with its color, ranked last; answers the
/// tag's name, `null` when dismissed or already there.
Future<String?> newQualityValue(BuildContext context, WidgetRef ref, Pool pool, String quality) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<(String, Color?)>(
    context: context,
    builder: (context) => _ValueDialog(
      title: '${l10n.addValue} · ${qualityLabel(l10n, quality)}',
      color: defaultValueColor(pool.valuesOf(quality).length),
    ),
  );
  if (result == null) return null;
  final (value, color) = result;
  final name = Pool.qualityTag(quality, value);
  if (pool.tags.containsKey(name)) return null;
  savePool(ref, pool.withTag(name, const []).withTagColor(name, color?.toARGB32()));
  return name;
}

/// Recolors a tag.
void setTagColor(WidgetRef ref, Pool pool, String tag, Color? color) =>
    savePool(ref, pool.withTagColor(tag, color?.toARGB32()));

/// Creates a quality (a discrete trait: one value among several) with its
/// first values and their colors, ranked as listed; answers its name,
/// `null` when dismissed, blank or already there.
Future<String?> newPoolQuality(BuildContext context, WidgetRef ref, Pool pool) async {
  final result = await showDialog<(String, List<(String, Color?)>)>(
    context: context,
    builder: (context) => const _NewQualityDialog(),
  );
  if (result == null) return null;
  final (quality, values) = result;
  if (pool.qualities.contains(quality)) return null;
  var updated = pool;
  for (final (value, color) in values) {
    final name = Pool.qualityTag(quality, value);
    updated = updated.withTag(name, const []).withTagColor(name, color?.toARGB32());
  }
  savePool(ref, updated);
  return quality;
}

/// Asks a value's name and color.
class _ValueDialog extends StatefulWidget {
  const _ValueDialog({required this.title, this.color});

  final String title;
  final Color? color;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late final _name = TextEditingController();
  late Color? _color = widget.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim().replaceAll(':', '');
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('valueNameField'),
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.valueName),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(l10n.valueColor, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          ColorPicker(value: _color, onChanged: (c) => setState(() => _color = c)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.apply)),
      ],
    );
  }
}

/// Asks a quality name and its values, best first, each with a color.
class _NewQualityDialog extends StatefulWidget {
  const _NewQualityDialog();

  @override
  State<_NewQualityDialog> createState() => _NewQualityDialogState();
}

class _NewQualityDialogState extends State<_NewQualityDialog> {
  late final _name = TextEditingController();
  final _values = <(TextEditingController, Color?)>[];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i++) {
      _addRow();
    }
  }

  void _addRow() => _values.add((TextEditingController(), defaultValueColor(_values.length)));

  @override
  void dispose() {
    _name.dispose();
    for (final (controller, _) in _values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim().replaceAll(':', '').toLowerCase();
    final seen = <String>{};
    final values = [
      for (final (controller, color) in _values)
        if (controller.text.trim().replaceAll(':', '') case final value when value.isNotEmpty && seen.add(value))
          (value, color),
    ];
    if (name.isEmpty || values.isEmpty) return;
    Navigator.pop(context, (name, values));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.newQualityTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.newQualityHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                key: const Key('qualityNameField'),
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.qualityName, hintText: 'power'),
              ),
              const SizedBox(height: 12),
              Text(l10n.qualityValues, style: theme.textTheme.labelLarge),
              Text(l10n.qualityValuesHint, style: theme.textTheme.bodySmall),
              for (final (i, (controller, color)) in _values.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text('${i + 1}.', style: theme.textTheme.labelLarge),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: ValueKey('qualityValue-$i'),
                          controller: controller,
                          decoration: InputDecoration(isDense: true, hintText: ['S', 'A', 'B', 'C'].elementAtOrNull(i)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<Color>(
                        key: ValueKey('qualityValueColor-$i'),
                        tooltip: l10n.valueColor,
                        icon: ColorDot(color, size: 24),
                        onSelected: (c) => setState(() => _values[i] = (controller, c)),
                        itemBuilder: (context) => [
                          for (final c in qualityPalette)
                            PopupMenuItem(value: c, child: ColorDot(c, size: 20)),
                        ],
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('addQualityValueRow'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addValue),
                  onPressed: () => setState(_addRow),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.apply)),
      ],
    );
  }
}

/// Deletes [tag] after a warning listing the slots pulling from it; they
/// lose that option, and go when nothing is left.
Future<void> deletePoolTag(BuildContext context, WidgetRef ref, PlayPool play, String tag) async {
  final l10n = AppLocalizations.of(context);
  final pool = play.pool;
  final affected = [
    for (final slot in pool.slots)
      if (slot.options.any((o) => o.tag == tag)) l10n.slotRow(slot.count, slotOptionsLabel(l10n, slot)),
  ];
  if (affected.isNotEmpty) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTagTitle(tagLabel(l10n, tag))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteTagAffects),
            const SizedBox(height: 8),
            for (final line in affected) Text('• $line'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.deleteTag)),
        ],
      ),
    );
    if (confirmed != true) return;
  }
  savePool(ref, pool.withoutTag(tag));
}

/// Asks for a name; owns its text controller for as long as the dialog
/// animates.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial, this.label});

  final String title;
  final String initial;
  final String? label;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(l10n.apply)),
      ],
    );
  }
}
