import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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

/// Where the pools' own booster pictures are kept on this device.
Future<Directory> poolCoversDirectory() async =>
    Directory('${(await getApplicationSupportDirectory()).path}/pools/covers');

/// Lets the user pick a picture file for the pool's booster, copied next
/// to the app's data so the original may go.
Future<void> pickPoolCover(BuildContext context, WidgetRef ref, Pool pool) async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return;
  final bytes = await file.readAsBytes();
  final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'png';
  final dir = await poolCoversDirectory();
  await dir.create(recursive: true);
  final target = File('${dir.path}/${pool.id}.$extension');
  await target.writeAsBytes(bytes, flush: true);
  if (pool.cover case final old? when old != target.path) {
    final previous = File(old);
    if (await previous.exists()) await previous.delete();
  }
  savePool(ref, pool.withCover(target.path));
}

/// Drops the pool's own booster picture, back to the set's.
Future<void> clearPoolCover(WidgetRef ref, Pool pool) async {
  if (pool.cover case final path?) {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
  savePool(ref, pool.withCover(null));
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

/// One value as the quality dialog edits it: the tag it came from (`null`
/// when new), its name and color.
typedef QualityValueEdit = ({String? tag, String value, Color? color, bool copiesSet, int? copies});

/// What the quality dialog answers: the quality's name and its values in
/// their preferred order; or a request to delete the whole quality.
typedef QualityEdit = ({String quality, List<QualityValueEdit> values, bool delete});

/// Creates a quality (a discrete trait: one value among several) with its
/// first values and their colors, ranked as listed; answers its name,
/// `null` when dismissed, blank or already there.
Future<String?> newPoolQuality(BuildContext context, WidgetRef ref, Pool pool) async {
  final edit = await showDialog<QualityEdit>(
    context: context,
    builder: (context) => const QualityDialog(),
  );
  if (edit == null || edit.delete) return null;
  if (pool.qualities.contains(edit.quality)) return null;
  var updated = pool;
  for (final (:tag, :value, :color, :copiesSet, :copies) in edit.values) {
    assert(tag == null);
    final name = Pool.qualityTag(edit.quality, value);
    updated = updated
        .withTag(name, const [])
        .withTagColor(name, color?.toARGB32())
        .withTagCopies(name, set: copiesSet, copies: copies);
  }
  savePool(ref, updated);
  return edit.quality;
}

/// Edits [quality] as a whole: its name, and its values' names, colors,
/// order, with values added or deleted; or deletes it. Answers the
/// quality's (new) name, `null` when dismissed or deleted.
Future<String?> editPoolQuality(BuildContext context, WidgetRef ref, Pool pool, String quality) async {
  final l10n = AppLocalizations.of(context);
  final edit = await showDialog<QualityEdit>(
    context: context,
    builder: (context) => QualityDialog(
      quality: quality,
      values: [
        for (final tag in pool.orderedValuesOf(quality))
          (
            tag: tag,
            value: tag.substring(quality.length + 1),
            color: valueColor(pool, tag),
            copiesSet: pool.tags[tag]!.copiesSet,
            copies: pool.tags[tag]!.copies,
          ),
      ],
      descending: pool.isDescending(quality),
    ),
  );
  if (edit == null || !context.mounted) return null;
  if (edit.delete) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteQualityTitle(qualityLabel(l10n, quality))),
        content: Text(l10n.deleteQualityAffects),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.deleteQuality)),
        ],
      ),
    );
    if (confirmed != true) return null;
    var updated = pool;
    for (final tag in pool.valuesOf(quality)) {
      updated = updated.withoutTag(tag);
    }
    savePool(ref, updated);
    return null;
  }
  savePool(ref, applyQualityEdit(pool, quality, edit));
  return edit.quality;
}

/// [pool] with [edit] applied to [quality]: values gone are deleted,
/// kept ones renamed and recolored, new ones created, all ranked as
/// listed; then the quality itself renamed when its name changed.
Pool applyQualityEdit(Pool pool, String quality, QualityEdit edit) {
  var updated = pool;
  final kept = {for (final v in edit.values) if (v.tag != null) v.tag!};
  for (final tag in pool.valuesOf(quality)) {
    if (!kept.contains(tag)) updated = updated.withoutTag(tag);
  }
  // Two passes: temporary names first, so swapping two values' names works.
  final finalNames = <String, String>{};
  for (final (i, (:tag, :value, :color, :copiesSet, :copies)) in edit.values.indexed) {
    final name = Pool.qualityTag(quality, value);
    if (tag == null) {
      updated = updated
          .withTag(name, const [])
          .withTagColor(name, color?.toARGB32())
          .withTagCopies(name, set: copiesSet, copies: copies);
      finalNames[name] = name;
    } else {
      final temporary = Pool.qualityTag(quality, '\u0000$i');
      updated = updated
          .withTagRenamed(tag, temporary)
          .withTagColor(temporary, color?.toARGB32())
          .withTagCopies(temporary, set: copiesSet, copies: copies);
      finalNames[temporary] = name;
    }
  }
  for (final MapEntry(key: from, value: to) in finalNames.entries) {
    updated = updated.withTagRenamed(from, to);
  }
  final shown = [for (final v in edit.values) Pool.qualityTag(quality, v.value)];
  updated = updated.withValuesOrder(quality, updated.isDescending(quality) ? shown.reversed.toList() : shown);
  if (edit.quality != quality) {
    for (final tag in updated.valuesOf(quality)) {
      updated = updated.withTagRenamed(tag, Pool.qualityTag(edit.quality, tag.substring(quality.length + 1)));
    }
  }
  return updated;
}

/// Asks a quality name and its values, best first, each with a color;
/// edits an existing one when [quality] is given, deletes it by a button.
class QualityDialog extends StatefulWidget {
  const QualityDialog({super.key, this.quality, this.values = const [], this.descending = false});

  final String? quality;
  final List<QualityValueEdit> values;
  final bool descending;

  @override
  State<QualityDialog> createState() => _QualityDialogState();
}

class _QualityDialogState extends State<QualityDialog> {
  late final _name = TextEditingController(text: widget.quality ?? '');
  final _rows = <({String? tag, TextEditingController name, Color? color, bool copiesSet, int? copies})>[];

  @override
  void initState() {
    super.initState();
    for (final (:tag, :value, :color, :copiesSet, :copies) in widget.values) {
      _rows.add((tag: tag, name: TextEditingController(text: value), color: color, copiesSet: copiesSet, copies: copies));
    }
    if (_rows.isEmpty) {
      for (var i = 0; i < 3; i++) {
        _addRow();
      }
    }
  }

  void _addRow() => _rows.add(
      (tag: null, name: TextEditingController(), color: defaultValueColor(_rows.length), copiesSet: false, copies: null));

  @override
  void dispose() {
    _name.dispose();
    for (final row in _rows) {
      row.name.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim().replaceAll(':', '').toLowerCase();
    final seen = <String>{};
    final values = <QualityValueEdit>[
      for (final row in _rows)
        if (row.name.text.trim().replaceAll(':', '') case final value when value.isNotEmpty && seen.add(value))
          (tag: row.tag, value: value, color: row.color, copiesSet: row.copiesSet, copies: row.copies),
    ];
    if (name.isEmpty || values.isEmpty) return;
    Navigator.pop(context, (quality: name, values: values, delete: false));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final editing = widget.quality != null;
    return AlertDialog(
      title: Text(editing ? l10n.editQualityTitle : l10n.newQualityTitle),
      content: SizedBox(
        width: 440,
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
                autofocus: !editing,
                decoration: InputDecoration(labelText: l10n.qualityName, hintText: 'power'),
              ),
              const SizedBox(height: 12),
              Text(l10n.qualityValues, style: theme.textTheme.labelLarge),
              Text(widget.descending ? l10n.qualityValuesHint : l10n.qualityValuesHintAscending,
                  style: theme.textTheme.bodySmall),
              Text(l10n.valueCopiesHint, style: theme.textTheme.bodySmall),
              for (final (i, row) in _rows.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('${i + 1}.', style: theme.textTheme.labelLarge),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: ValueKey('qualityValue-$i'),
                          controller: row.name,
                          decoration: InputDecoration(isDense: true, hintText: ['S', 'A', 'B', 'C'].elementAtOrNull(i)),
                        ),
                      ),
                      PopupMenuButton<Color>(
                        key: ValueKey('qualityValueColor-$i'),
                        tooltip: l10n.valueColor,
                        icon: ColorDot(row.color, size: 24),
                        onSelected: (c) => setState(() => _rows[i] =
                            (tag: row.tag, name: row.name, color: c, copiesSet: row.copiesSet, copies: row.copies)),
                        itemBuilder: (context) => [
                          for (final c in qualityPalette)
                            PopupMenuItem(value: c, child: ColorDot(c, size: 20)),
                        ],
                      ),
                      // Copies: left to the pool (—), unlimited (∞) or a count.
                      Tooltip(
                        message: l10n.valueCopies,
                        child: DropdownButton<int>(
                          key: ValueKey('qualityValueCopies-$i'),
                          value: row.copiesSet ? (row.copies ?? -1) : -2,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            DropdownMenuItem(value: -2, child: Text('×—', style: theme.textTheme.labelLarge)),
                            DropdownMenuItem(value: -1, child: Text('×∞', style: theme.textTheme.labelLarge)),
                            for (var n = 0; n <= PresetPicker.maxCopies; n++)
                              DropdownMenuItem(value: n, child: Text('×$n', style: theme.textTheme.labelLarge)),
                          ],
                          onChanged: (v) => setState(() => _rows[i] = (
                                tag: row.tag,
                                name: row.name,
                                color: row.color,
                                copiesSet: v != -2,
                                copies: v == null || v < 0 ? null : v,
                              )),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('qualityValueUp-$i'),
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: i == 0 ? null : () => setState(() => _rows.insert(i - 1, _rows.removeAt(i))),
                      ),
                      IconButton(
                        key: ValueKey('qualityValueDown-$i'),
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: i == _rows.length - 1
                            ? null
                            : () => setState(() => _rows.insert(i + 1, _rows.removeAt(i))),
                      ),
                      IconButton(
                        key: ValueKey('qualityValueDelete-$i'),
                        tooltip: l10n.deleteValue,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _rows.removeAt(i).name.dispose()),
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
        if (editing)
          TextButton.icon(
            key: const Key('deleteQuality'),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.deleteQuality),
            onPressed: () => Navigator.pop(context, (quality: widget.quality!, values: <QualityValueEdit>[], delete: true)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.apply)),
      ],
    );
  }
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
