import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../../cube/data/cube_repository.dart';
import '../../pools/domain/play_pool.dart';
import '../../pools/domain/pool.dart';
import '../../pools/presentation/pool_view.dart';
import '../data/card_search.dart';
import '../domain/card_filter.dart';
import 'card_search_sheet.dart';
import 'labels.dart';

/// A side panel of the pool editor: searches cards online (text, facets,
/// sort) and lays the results out like the pool itself, in the view the
/// editor shows. Tapping a result adds it to the pool as a picked card,
/// tapping it again takes it out; cards brought by a set or a cube of the
/// pool are shown as such.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({
    super.key,
    required this.pool,
    required this.onAdd,
    required this.onRemove,
    required this.onClose,
  });

  final PlayPool pool;
  final void Function(FoundCard found) onAdd;
  final void Function(CardData card) onRemove;
  final VoidCallback onClose;

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  SearchQuery _query = const SearchQuery();
  CardSort _sort = CardSort.name;
  List<FoundCard>? _results;
  bool _hasMore = false;
  bool _searching = false;
  bool _facetsShown = false;
  String? _error;

  Game get _game => widget.pool.pool.game;

  Future<void> _search() async {
    final search = ref.read(cardSearchProvider);
    if (search == null || _query.isEmpty || _searching) return;
    final language = dataLanguage(ref, context);
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final frenchNames = _game == Game.mtg && language == 'fr'
          ? await mtgFrenchNames(ref.read(catalogRepositoryProvider))
          : const <String, String>{};
      final found = await search.search(_game, _query, language: language, frenchNames: frenchNames);
      if (!mounted) return;
      setState(() {
        _results = found.cards;
        _hasMore = found.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Whether [card] is in the pool, and whether a set or cube brought it
  /// (then the panel cannot take it out).
  ({bool inPool, bool fromSource}) _status(CardData card) {
    final pool = widget.pool.pool;
    final picked = pool.sources.whereType<CardsSource>().any((s) => s.cards.any((c) => c.id == card.id));
    final inPool = widget.pool.entries.any((e) => e.card.id == card.id);
    return (inPool: inPool, fromSource: inPool && !picked);
  }

  /// The full search page, with checkboxes: every card ticked there is
  /// added.
  Future<void> _advanced() async {
    final found = await showCardSearch(
      context,
      game: _game,
      excludeIds: {for (final e in widget.pool.entries) e.card.id},
    );
    for (final f in found ?? const <FoundCard>[]) {
      widget.onAdd(f);
    }
  }

  void _toggle(CardData card) {
    final status = _status(card);
    if (status.fromSource) return;
    if (status.inPool) return widget.onRemove(card);
    final found = _results?.where((f) => f.card.id == card.id).firstOrNull;
    if (found != null) widget.onAdd(found);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = dataLanguage(ref, context);
    final view = ref.watch(poolViewProvider);
    final results = _results;

    final items = [
      for (final found in results ?? const <FoundCard>[])
        (card: found.card, info: found.info, tags: const <String>{}),
    ]..sort((a, b) => _sort.compare(a, b, language));

    final actions = PoolCardActions(
      copiesOf: (_) => null,
      listedOf: (_) => 1,
      changed: (card) => _status(card).inPool,
      setCopies: (_, _) {},
      tint: (card) => switch (_status(card)) {
        (inPool: true, fromSource: true) => Colors.grey,
        (inPool: true, fromSource: false) => Colors.green,
        _ => null,
      },
      onTags: (_) {},
      tagsOf: (card) => switch (_status(card)) {
        (inPool: true, fromSource: true) => [l10n.cardFromSource],
        (inPool: true, fromSource: false) => [l10n.cardInPool],
        _ => const [],
      },
      onTap: _toggle,
      trailing: (card) {
        final status = _status(card);
        return IconButton(
          key: ValueKey('result-${card.id}'),
          tooltip: status.inPool ? l10n.cardInPool : l10n.addSelected,
          icon: Icon(status.inPool ? Icons.check_circle : Icons.add_circle_outline),
          color: status.inPool ? Colors.green : null,
          onPressed: status.fromSource ? null : () => _toggle(card),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Expanded(child: Text(l10n.searchPanel, style: theme.textTheme.titleMedium)),
              IconButton(tooltip: l10n.cancel, icon: const Icon(Icons.close), onPressed: widget.onClose),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('panelSearch'),
                  decoration: InputDecoration(
                    labelText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (text) => setState(() => _query = _query.copyWith(text: text)),
                  onSubmitted: (_) => _search(),
                ),
              ),
              IconButton(
                tooltip: l10n.filters,
                isSelected: _facetsShown,
                icon: const Icon(Icons.filter_list),
                onPressed: () => setState(() => _facetsShown = !_facetsShown),
              ),
              PopupMenuButton<CardSort>(
                tooltip: l10n.sortBy,
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (sort) => setState(() => _sort = sort),
                itemBuilder: (context) => [
                  for (final sort in CardSort.forGame(_game))
                    CheckedPopupMenuItem(value: sort, checked: sort == _sort, child: Text(sortLabel(l10n, sort))),
                ],
              ),
              IconButton.filled(
                tooltip: l10n.searchButton,
                icon: _searching
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                onPressed: _searching || _query.isEmpty ? null : _search,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('advancedSearch'),
              icon: const Icon(Icons.manage_search),
              label: Text(l10n.advancedSearch),
              onPressed: _advanced,
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (_facetsShown)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SearchFacets(
                      game: _game,
                      query: _query,
                      onChanged: (query) => setState(() => _query = query),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: switch ((results, _error)) {
                    (_, final error?) =>
                      Text(l10n.searchFailed(error), style: TextStyle(color: theme.colorScheme.error)),
                    (null, _) => Text(l10n.searchPanelHint, style: theme.textTheme.bodySmall),
                    ([], _) => Text(l10n.noResults),
                    (final found?, _) => Text(
                        [l10n.cardsCount(found.length), if (_hasMore) l10n.moreResults].join(' · '),
                        style: theme.textTheme.labelMedium,
                      ),
                  },
                ),
              ),
              if (items.isNotEmpty)
                switch (view) {
                  PoolView.list => PoolListSliver(items: items, actions: actions, language: language),
                  PoolView.gallery => PoolGallerySliver(items: items, actions: actions),
                  PoolView.stacks => PoolStacksSliver(
                      items: items,
                      actions: actions,
                      labelOf: (item) => [stackLabel(_sort, item, language)],
                      header: (label) => valueLabel(l10n, label),
                    ),
                  PoolView.spoiler => PoolSpoilerSliver(items: items, actions: actions, language: language),
                },
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ],
    );
  }
}
