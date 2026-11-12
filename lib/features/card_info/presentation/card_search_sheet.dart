import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../../cube/data/cube_repository.dart';
import '../data/card_search.dart';
import 'labels.dart';

/// `null` disables online search (tests).
final cardSearchProvider = Provider<CardSearch?>((ref) => CardSearch());

/// Searches cards online with the editor's facets and returns the ones the
/// user ticked, or `null` when dismissed. Cards in [excludeIds] are shown
/// as already in the pool.
Future<List<FoundCard>?> showCardSearch(
  BuildContext context, {
  required Game game,
  Set<String> excludeIds = const {},
}) =>
    showDialog<List<FoundCard>>(
      context: context,
      builder: (context) => Dialog.fullscreen(child: _CardSearch(game: game, excludeIds: excludeIds)),
    );

class _CardSearch extends ConsumerStatefulWidget {
  const _CardSearch({required this.game, required this.excludeIds});

  final Game game;
  final Set<String> excludeIds;

  @override
  ConsumerState<_CardSearch> createState() => _CardSearchState();
}

class _CardSearchState extends ConsumerState<_CardSearch> {
  SearchQuery _query = const SearchQuery();
  List<FoundCard>? _results;
  bool _hasMore = false;
  bool _searching = false;
  String? _error;
  final _selected = <String, FoundCard>{};

  Future<void> _search() async {
    final search = ref.read(cardSearchProvider);
    if (search == null || _query.isEmpty || _searching) return;
    final language = dataLanguage(ref, context);
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final frenchNames = widget.game == Game.mtg && language == 'fr'
          ? await mtgFrenchNames(ref.read(catalogRepositoryProvider))
          : const <String, String>{};
      final found = await search.search(widget.game, _query, language: language, frenchNames: frenchNames);
      setState(() {
        _results = found.cards;
        _hasMore = found.hasMore;
      });
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _update(SearchQuery query) => setState(() => _query = query);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = dataLanguage(ref, context);
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchOnline),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                TextField(
                  decoration: InputDecoration(labelText: l10n.searchHint, prefixIcon: const Icon(Icons.search)),
                  textInputAction: TextInputAction.search,
                  onChanged: (text) => _update(_query.copyWith(text: text)),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                ...switch (widget.game) {
                  Game.mtg => _mtgFacets(l10n, theme),
                  Game.ygo => _ygoFacets(l10n, theme),
                },
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: _searching
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(l10n.searchButton),
                  onPressed: _searching || _query.isEmpty ? null : _search,
                ),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(l10n.searchFailed(error), style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (results != null) ...[
                  const SizedBox(height: 12),
                  if (results.isEmpty) Text(l10n.noResults),
                  for (final found in results)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected.containsKey(found.card.id) || widget.excludeIds.contains(found.card.id),
                      enabled: !widget.excludeIds.contains(found.card.id),
                      title: Text(found.card.nameFor(language)),
                      subtitle: Text([
                        '${found.card.id} · ${found.card.rarity.label(l10n)}',
                        ?cardInfoLine(found.info),
                      ].join('\n')),
                      isThreeLine: true,
                      onChanged: (checked) => setState(() {
                        checked == true ? _selected[found.card.id] = found : _selected.remove(found.card.id);
                      }),
                    ),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l10n.moreResults, style: theme.textTheme.bodySmall),
                    ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.selectedCount(_selected.length))),
                  FilledButton(
                    onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.values.toList()),
                    child: Text(l10n.addSelected),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, ThemeData theme, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title, style: theme.textTheme.labelLarge), const SizedBox(height: 4), child],
        ),
      );

  Widget _chips<T>(Iterable<T> values, Set<T> chosen, String Function(T) label, ValueChanged<Set<T>> onChanged) =>
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final value in values)
            FilterChip(
              label: Text(label(value)),
              selected: chosen.contains(value),
              onSelected: (on) => onChanged(on ? {...chosen, value} : {...chosen}..remove(value)),
            ),
        ],
      );

  Widget _range(String title, ThemeData theme, (int, int)? range, int low, int high, int step,
      ValueChanged<(int, int)?> onChanged) {
    final (min, max) = range ?? (low, high);
    return _section(
      '$title · ${range == null ? '—' : '$min – $max'}',
      theme,
      RangeSlider(
        values: RangeValues(min.toDouble(), max.toDouble()),
        min: low.toDouble(),
        max: high.toDouble(),
        divisions: (high - low) ~/ step,
        onChanged: (values) {
          final next = (values.start.round(), values.end.round());
          onChanged(next == (low, high) ? null : next);
        },
      ),
    );
  }

  List<Widget> _mtgFacets(AppLocalizations l10n, ThemeData theme) => [
        _section(l10n.facetRarity, theme,
            _chips(Rarity.values.take(4), _query.rarities, (r) => r.label(l10n), (v) => _update(_query.copyWith(rarities: v)))),
        _section(l10n.facetColor, theme,
            _chips(const ['W', 'U', 'B', 'R', 'G', 'C'], _query.colors, (c) => valueLabel(l10n, c), (v) => _update(_query.copyWith(colors: v)))),
        _section(l10n.facetType, theme,
            _chips(mtgSearchTypes, _query.types, (t) => t, (v) => _update(_query.copyWith(types: v)))),
        _range(l10n.facetManaValue, theme, _query.manaValue, 0, 10, 1, (r) => _update(_query.copyWith(manaValue: () => r))),
        _section(
          l10n.facetKeyword,
          theme,
          TextField(
            decoration: const InputDecoration(hintText: 'Flying, Trample…', isDense: true),
            onChanged: (text) => _update(_query.copyWith(keywords: {
              for (final k in text.split(',')) if (k.trim().isNotEmpty) k.trim(),
            })),
          ),
        ),
        _section(
          l10n.facetSet,
          theme,
          TextField(
            decoration: const InputDecoration(hintText: 'DMU', isDense: true),
            onChanged: (text) => _update(_query.copyWith(setCode: text)),
          ),
        ),
      ];

  List<Widget> _ygoFacets(AppLocalizations l10n, ThemeData theme) => [
        _section(l10n.facetKind, theme,
            _chips(ygoSearchTypes, _query.ygoTypes, (t) => t, (v) => _update(_query.copyWith(ygoTypes: v)))),
        _section(l10n.facetAttribute, theme,
            _chips(ygoAttributes, _query.attributes, (a) => a, (v) => _update(_query.copyWith(attributes: v)))),
        _section(
          l10n.facetRace,
          theme,
          TextField(
            decoration: const InputDecoration(hintText: 'Dragon, Spellcaster…', isDense: true),
            onChanged: (text) => _update(_query.copyWith(race: text)),
          ),
        ),
        _section(
          l10n.facetArchetype,
          theme,
          TextField(
            decoration: const InputDecoration(hintText: 'Blue-Eyes', isDense: true),
            onChanged: (text) => _update(_query.copyWith(archetype: text)),
          ),
        ),
        _range(l10n.facetLevel, theme, _query.level, 1, 12, 1, (r) => _update(_query.copyWith(level: () => r))),
        _range(l10n.facetAtk, theme, _query.atk, 0, 5000, 100, (r) => _update(_query.copyWith(atk: () => r))),
        _range(l10n.facetDef, theme, _query.def, 0, 5000, 100, (r) => _update(_query.copyWith(def: () => r))),
      ];
}
