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

/// Creates an empty tag, plain or within a quality (a group of exclusive
/// tags, like the rarities), and answers its name; `null` when dismissed
/// or already taken.
Future<String?> newPoolTag(BuildContext context, WidgetRef ref, Pool pool, {String? quality}) async {
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => _NewTagDialog(qualities: pool.qualities, quality: quality),
  );
  if (result == null) return null;
  final (value, chosenQuality) = result;
  final name = chosenQuality.isEmpty ? value : Pool.qualityTag(chosenQuality, value);
  if (pool.tags.containsKey(name)) return null;
  savePool(ref, pool.withTag(name, const []));
  return name;
}

/// Asks a tag name and, optionally, the quality it belongs to.
class _NewTagDialog extends StatefulWidget {
  const _NewTagDialog({required this.qualities, this.quality});

  final List<String> qualities;
  final String? quality;

  @override
  State<_NewTagDialog> createState() => _NewTagDialogState();
}

class _NewTagDialogState extends State<_NewTagDialog> {
  late final _name = TextEditingController();
  late final _quality = TextEditingController(text: widget.quality ?? '');

  @override
  void dispose() {
    _name.dispose();
    _quality.dispose();
    super.dispose();
  }

  String _clean(String s) => s.trim().replaceAll(':', '');

  void _submit() {
    final name = _clean(_name.text);
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _clean(_quality.text).toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newTag),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('tagNameField'),
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.tagName),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('tagQualityField'),
            controller: _quality,
            decoration: InputDecoration(labelText: l10n.tagQuality, helperText: l10n.tagQualityHint),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.qualities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final quality in widget.qualities)
                  ActionChip(
                    label: Text(qualityLabel(l10n, quality)),
                    onPressed: () => setState(() => _quality.text = quality),
                  ),
              ],
            ),
          ],
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
