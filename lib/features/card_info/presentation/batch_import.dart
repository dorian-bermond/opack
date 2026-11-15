import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../../cube/data/cube_repository.dart';
import '../../pools/domain/pool.dart';
import '../data/card_search.dart';
import 'card_search_sheet.dart';
import 'labels.dart';

/// One line of a pasted list: how many copies and the card's name.
typedef ListLine = ({int count, String name});

/// Reads a decklist: one card per line, as `1 Name`, `1x Name`, `Name x1`
/// or just `Name`; blank lines and lone numbers are skipped.
List<ListLine> parseCardList(String text) {
  final lines = <ListLine>[];
  for (final raw in text.split('\n')) {
    var line = raw.trim();
    if (line.isEmpty || RegExp(r'^\d+$').hasMatch(line)) continue;
    var count = 1;
    if (RegExp(r'^(\d+)\s*[xX]?\s+(.+)$').firstMatch(line) case final m?) {
      count = int.parse(m.group(1)!);
      line = m.group(2)!.trim();
    } else if (RegExp(r'^(.+?)\s+[xX]\s*(\d+)$').firstMatch(line) case final m?) {
      count = int.parse(m.group(2)!);
      line = m.group(1)!.trim();
    }
    lines.add((count: count < 1 ? 1 : count, name: line));
  }
  return lines;
}

/// What a batch import yields: the cards found, by the line they came
/// from, the lines nothing matched, and the tags to give them all.
typedef BatchImport = ({List<FoundCard> found, List<String> unknown, Set<String> tags});

/// Pastes a list of card names, looks each one up online and answers the
/// cards found with the tags chosen for the whole batch; `null` when
/// dismissed.
Future<BatchImport?> showBatchImport(BuildContext context, {required Pool pool}) => showDialog<BatchImport>(
      context: context,
      builder: (context) => _BatchImportDialog(pool: pool),
    );

class _BatchImportDialog extends ConsumerStatefulWidget {
  const _BatchImportDialog({required this.pool});

  final Pool pool;

  @override
  ConsumerState<_BatchImportDialog> createState() => _BatchImportDialogState();
}

class _BatchImportDialogState extends ConsumerState<_BatchImportDialog> {
  final _text = TextEditingController();
  final _newTag = TextEditingController();
  final _tags = <String>{};
  List<FoundCard>? _found;
  List<String> _unknown = const [];
  int _done = 0;
  int _total = 0;
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _newTag.dispose();
    super.dispose();
  }

  /// Looks every line up, one search each: the result named exactly like
  /// the line wins, else the first one.
  Future<void> _lookUp() async {
    final search = ref.read(cardSearchProvider);
    final lines = parseCardList(_text.text);
    if (search == null || lines.isEmpty || _running) return;
    final language = dataLanguage(ref, context);
    final game = widget.pool.game;
    setState(() {
      _running = true;
      _error = null;
      _found = null;
      _done = 0;
      _total = lines.length;
    });
    final frenchNames = game == Game.mtg && language == 'fr'
        ? await mtgFrenchNames(ref.read(catalogRepositoryProvider))
        : const <String, String>{};
    final found = <FoundCard>[];
    final unknown = <String>[];
    final seen = <String>{};
    try {
      for (final (:count, :name) in lines) {
        final result = await search.search(game, SearchQuery(text: name), language: language, frenchNames: frenchNames);
        final wanted = name.toLowerCase();
        final exact = result.cards.where((f) =>
            f.card.names.values.any((n) => n.toLowerCase() == wanted) || f.info.name.toLowerCase() == wanted);
        final best = exact.firstOrNull ?? result.cards.firstOrNull;
        if (best == null) {
          unknown.add(name);
        } else if (seen.add(best.card.id)) {
          found.add(best);
        }
        if (count > 1 && best != null) {
          // Copies are set by the pool's card counts; a list is one of each.
        }
        if (!mounted) return;
        setState(() => _done++);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _found = found;
          _unknown = unknown;
        });
      }
    }
  }

  void _addNewTag() {
    final name = _newTag.text.trim().replaceAll(':', '');
    if (name.isEmpty) return;
    setState(() {
      _tags.add(name);
      _newTag.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final found = _found;
    final existing = widget.pool.plainTags;
    final added = _tags.where((t) => !existing.contains(t)).toList();

    return AlertDialog(
      title: Text(l10n.batchImport),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.batchImportHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              TextField(
                key: const Key('batchList'),
                controller: _text,
                minLines: 6,
                maxLines: 14,
                enabled: !_running,
                decoration: InputDecoration(
                  hintText: '1 Mezuki\n1 Gozuki\nPyramid Turtle',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('batchLookUp'),
                    icon: _running
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.travel_explore),
                    label: Text(l10n.batchLookUp),
                    onPressed: _running ? null : _lookUp,
                  ),
                  const SizedBox(width: 12),
                  if (_running) Text('$_done / $_total', style: theme.textTheme.labelMedium),
                ],
              ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.searchFailed(error), style: TextStyle(color: theme.colorScheme.error)),
                ),
              if (found != null) ...[
                const SizedBox(height: 12),
                Text(l10n.batchFound(found.length, _unknown.length), style: theme.textTheme.labelLarge),
                if (_unknown.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _unknown.join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(l10n.batchTags, style: theme.textTheme.labelLarge),
                Text(l10n.batchTagsHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in [...existing, ...added])
                      FilterChip(
                        key: ValueKey('batchTag-$tag'),
                        label: Text(tagLabel(l10n, tag)),
                        selected: _tags.contains(tag),
                        onSelected: (on) => setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('batchNewTag'),
                        controller: _newTag,
                        decoration: InputDecoration(labelText: l10n.newTag, isDense: true),
                        onSubmitted: (_) => _addNewTag(),
                      ),
                    ),
                    IconButton(
                      key: const Key('batchAddTag'),
                      tooltip: l10n.newTag,
                      icon: const Icon(Icons.add),
                      onPressed: _addNewTag,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('batchApply'),
          onPressed: found == null || found.isEmpty
              ? null
              : () => Navigator.pop(context, (found: found, unknown: _unknown, tags: {..._tags})),
          child: Text(l10n.batchAdd),
        ),
      ],
    );
  }
}
