import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../../cube/data/cube_repository.dart';
import '../../pools/domain/pool.dart';
import '../../pools/presentation/pool_widgets.dart';
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
/// from, the lines nothing matched, the tags to give them all (plain tags
/// and `quality:value` ones, one value per quality) and whether they join
/// the tags of their rarities.
typedef BatchImport = ({List<FoundCard> found, List<String> unknown, Set<String> tags, bool rarities});

/// Pastes a list of card names and looks each one up online (first tab),
/// then asks how the cards found come in (second tab, open once looked
/// up): their tags, a value per quality, and whether their rarities are
/// imported. Answers the cards with those choices; `null` when dismissed.
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

class _BatchImportDialogState extends ConsumerState<_BatchImportDialog> with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  final _newTag = TextEditingController();
  final _tags = <String>{};

  /// The value chosen for each quality, as its `quality:value` tag.
  final _values = <String, String>{};

  /// Whether the cards join the tags of their rarities.
  bool _rarities = true;

  /// The list, then the options once it is looked up.
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      // The options need cards: back to the list until some are found.
      if (_tabs.index == 1 && !(_found?.isNotEmpty ?? false)) _tabs.index = 0;
      setState(() {});
    });
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
    _tabs.dispose();
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
        // Looked up: on to the options.
        if (found.isNotEmpty && _error == null) _tabs.index = 1;
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
    final found = _found;
    final ready = found != null && found.isNotEmpty;

    return AlertDialog(
      title: Text(l10n.batchImport),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: _tabs,
              tabs: [
                Tab(key: const Key('batchTabList'), text: l10n.batchTabList),
                Opacity(
                  opacity: ready ? 1 : 0.4,
                  child: Tab(key: const Key('batchTabOptions'), text: l10n.batchTabOptions),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: _tabs.index == 0 || !ready ? _listTab(context) : _optionsTab(context, found),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        if (ready && _tabs.index == 0)
          TextButton(
            key: const Key('batchNext'),
            onPressed: () => _tabs.index = 1,
            child: Text(l10n.batchTabOptions),
          ),
        FilledButton(
          key: const Key('batchApply'),
          onPressed: !ready || _running
              ? null
              : () => Navigator.pop(context, (
                    found: found,
                    unknown: _unknown,
                    tags: {..._tags, ..._values.values},
                    rarities: _rarities,
                  )),
          child: Text(l10n.batchAdd),
        ),
      ],
    );
  }

  /// What the look-up found, and the lines it did not.
  List<Widget> _outcome(BuildContext context, List<FoundCard> found) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return [
      Text(l10n.batchFound(found.length, _unknown.length), style: theme.textTheme.labelLarge),
      if (_unknown.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _unknown.join(', '),
            key: const Key('batchUnknown'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ),
    ];
  }

  /// The pasted list and its look-up.
  Widget _listTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
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
          decoration: const InputDecoration(
            hintText: '1 Mezuki\n1 Gozuki\nPyramid Turtle',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
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
        if (_found case final found?) ...[
          const SizedBox(height: 12),
          ..._outcome(context, found),
        ],
      ],
    );
  }

  /// How the cards found come into the pool: tags, quality values, rarities.
  Widget _optionsTab(BuildContext context, List<FoundCard> found) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pool = widget.pool;
    final existing = pool.plainTags;
    final added = _tags.where((t) => !existing.contains(t)).toList();
    // The rarities have their own switch.
    final qualities = [
      for (final quality in pool.qualities)
        if (quality != 'rarity' && quality != printedRarityQuality) quality,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._outcome(context, found),
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
        if (qualities.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.batchQualities, style: theme.textTheme.labelLarge),
          Text(l10n.batchQualitiesHint, style: theme.textTheme.bodySmall),
          for (final quality in qualities) ...[
            const SizedBox(height: 8),
            Text(qualityLabel(l10n, quality), style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in pool.orderedValuesOf(quality))
                  ChoiceChip(
                    key: ValueKey('batchValue-$value'),
                    avatar: ColorDot(valueColor(pool, value), size: 14),
                    label: Text(tagLabel(l10n, value.substring(quality.length + 1))),
                    selected: _values[quality] == value,
                    showCheckmark: false,
                    onSelected: (on) => setState(() => on ? _values[quality] = value : _values.remove(quality)),
                  ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('batchRarities'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.batchRarities),
          subtitle: Text(l10n.batchRaritiesHint),
          value: _rarities,
          onChanged: (on) => setState(() => _rarities = on),
        ),
      ],
    );
  }
}
