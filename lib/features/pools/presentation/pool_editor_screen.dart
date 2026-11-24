import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/settings/ygo_settings.dart';
import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/images/card_image_cache.dart';
import '../../card_info/data/card_info_repository.dart';
import '../../card_info/data/card_search.dart';
import '../../card_info/presentation/batch_import.dart';
import '../../card_info/domain/card_filter.dart';
import '../../card_info/domain/card_info.dart';
import '../../card_info/presentation/card_search_sheet.dart';
import '../../card_info/presentation/filter_sheet.dart';
import '../../card_info/presentation/labels.dart';
import '../../card_info/presentation/metrics_sheet.dart';
import '../../card_info/presentation/search_panel.dart';
import '../../card_text/presentation/card_details_sheet.dart';
import '../../catalog/domain/models.dart';
import '../data/pool_repository.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'marquee_selection.dart';
import 'pool_actions.dart';
import 'pool_loader.dart';
import 'pool_widgets.dart';
import 'pool_view.dart';

/// Edits a saved pool: its name, sources, pack layout and the copies of
/// each card.
class PoolEditorScreen extends StatelessWidget {
  const PoolEditorScreen({super.key, required this.poolId, this.taggingTag});

  final String poolId;

  /// A tag to start picking cards for right away (from the details page).
  final String? taggingTag;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => _PoolEditor(pool: pool, taggingTag: taggingTag),
      );
}

class _PoolEditor extends ConsumerStatefulWidget {
  const _PoolEditor({required this.pool, this.taggingTag});

  final PlayPool pool;
  final String? taggingTag;

  @override
  ConsumerState<_PoolEditor> createState() => _PoolEditorState();
}

class _PoolEditorState extends ConsumerState<_PoolEditor> {
  String _query = '';
  CardSort _sort = CardSort.rarity;
  GroupBy _groupBy = GroupBy.none;

  /// A second grouping inside each primary group.
  GroupBy _groupBy2 = GroupBy.none;

  /// The quality each grouping is narrowed to, `null` for every quality.
  String? _groupQuality;
  String? _groupQuality2;

  /// Asks which quality a quality grouping takes, when the pool has
  /// several; `null` for all of them. Answers `false` when dismissed.
  Future<(bool, String?)> _askQuality() async {
    final qualities = _pool.qualities;
    if (qualities.length < 2) return (true, null);
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(l10n.groupWhichQuality, style: Theme.of(context).textTheme.titleMedium)),
            ListTile(
              key: const Key('groupAllQualities'),
              leading: const Icon(Icons.select_all),
              title: Text(l10n.allQualities),
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final quality in qualities)
              ListTile(
                key: ValueKey('groupQuality-$quality'),
                leading: const Icon(Icons.category_outlined),
                title: Text(qualityLabel(l10n, quality)),
                onTap: () => Navigator.pop(context, quality),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return (false, null);
    return (true, chosen.isEmpty ? null : chosen);
  }

  Future<void> _selectGroup(GroupBy group) async {
    var quality = _groupQuality;
    if (group.asksQuality) {
      final (ok, chosen) = await _askQuality();
      if (!ok) return;
      quality = chosen;
    }
    setState(() {
      _groupBy = group;
      _groupQuality = quality;
      if (group == GroupBy.none || group == _groupBy2) _groupBy2 = GroupBy.none;
    });
  }

  Future<void> _selectGroup2(GroupBy group) async {
    var quality = _groupQuality2;
    if (group.asksQuality) {
      final (ok, chosen) = await _askQuality();
      if (!ok) return;
      quality = chosen;
    }
    setState(() {
      _groupBy2 = group;
      _groupQuality2 = quality;
    });
  }

  /// A grouping's name, with the quality it is narrowed to.
  String _groupName(AppLocalizations l10n, GroupBy group, String? quality) =>
      quality == null ? groupLabel(l10n, group) : '${groupLabel(l10n, group)} · ${qualityLabel(l10n, quality)}';

  /// Group labels folded away by the user.
  final Set<String> _collapsed = {};
  CardFilter _filter = const CardFilter();

  /// Which card list a download was already asked for, so it runs once.
  String? _fetchedFor;

  /// Whether the search panel is open beside (or over) the pool.
  bool _searchOpen = false;

  /// The panel's share of the window, dragged by the user.
  double _panelShare = 0.4;

  /// Tag basket mode: one basket per tag above the cards, which are
  /// dragged onto them to get the tag.
  bool _baskets = false;

  /// The pools before each drop, newest last, for Ctrl+Z.
  final List<Pool> _undo = [];

  /// Gives [card] the tag of [basket], remembering the pool for undo.
  void _dropOnBasket(String basket, CardData card) {
    final pool = _pool;
    final ids = {for (final c in widget.pool.tagCards[basket] ?? const <CardData>[]) c.id};
    if (!ids.add(card.id)) return;
    setState(() => _undo.add(pool));
    _save(_withTagCards(pool, basket, ids));
  }

  /// Restores the pool as it was before the last drop.
  void _undoDrop() {
    if (_undo.isEmpty) return;
    final previous = _undo.removeLast();
    setState(() {});
    _save(previous.copyWith());
  }

  Pool get _pool => widget.pool.pool;

  @override
  void initState() {
    super.initState();
    if (widget.taggingTag case final tag? when widget.pool.pool.tags.containsKey(tag)) {
      _startTagging(tag, (widget.pool.tagCards[tag] ?? const []).map((c) => c.id));
    }
  }

  /// Downloads the details still missing, once per card list, when online
  /// downloads are allowed and the last attempt did not fail.
  void _fetchMissing(CardInfoState? infos, List<CardData> cards, String language) {
    if (infos == null || infos.fetching || infos.failed) return;
    if (!ref.read(cardImagesEnabledProvider)) return;
    final key = '${_pool.id}:${cards.length}:$language';
    if (_fetchedFor == key) return;
    _fetchedFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(poolCardInfoProvider(_pool.id).notifier).fetchMissing(_pool.game, cards, language: language);
      }
    });
  }

    /// Adds one found card as a picked card, with its details; it joins the
  /// rarity tags so it gets dealt.
  Future<void> _addFound(FoundCard found) async {
    final pool = _pool;
    final picked = pool.sources.whereType<CardsSource>().firstOrNull ?? const CardsSource([]);
    final rest = [for (final source in pool.sources) if (source is! CardsSource) source];
    _save(pool.copyWith(sources: rest).withSource(
      picked.plus([found.card]),
      cards: [found.card],
      existing: widget.pool.entries.map((e) => e.card),
    ));
    await ref.read(poolCardInfoProvider(pool.id).notifier).addInfos({found.card.id: found.info});
  }

  /// Adds every card of [batch] as picked cards, with their details, and
  /// gives them all the batch's tags (created when new) and quality values
  /// (a card leaving the other values of that quality); they join the
  /// rarity tags only when the batch imports rarities.
  Future<void> _addBatch(BatchImport batch) async {
    final pool = _pool;
    final picked = pool.sources.whereType<CardsSource>().firstOrNull ?? const CardsSource([]);
    final rest = [for (final source in pool.sources) if (source is! CardsSource) source];
    final cards = [for (final f in batch.found) f.card];
    var updated = pool.copyWith(sources: rest).withSource(
      picked.plus(cards),
      cards: cards,
      existing: widget.pool.entries.map((e) => e.card),
      rarities: batch.rarities,
    );
    final added = {for (final c in cards) c.id};
    for (final tag in batch.tags) {
      // A quality holds one value per card: out of the other ones.
      if (Pool.qualityOf(tag) case final quality?) {
        for (final other in updated.valuesOf(quality)) {
          final held = updated.tags[other]!.cards;
          if (other != tag && held.any(added.contains)) {
            updated = updated.withTag(other, [for (final id in held) if (!added.contains(id)) id]);
          }
        }
      }
      updated = updated.withTag(tag, {...?updated.tags[tag]?.cards, ...added});
    }
    _save(updated);
    await ref.read(poolCardInfoProvider(pool.id).notifier).addInfos({for (final f in batch.found) f.card.id: f.info});
  }

  /// Takes a picked card out of the pool.
  void _removePicked(CardData card) {
    final pool = _pool;
    _save(pool.copyWith(sources: [
      for (final source in pool.sources)
        if (source case CardsSource(:final cards)) ...[
          if (cards.any((c) => c.id != card.id)) CardsSource([for (final c in cards) if (c.id != card.id) c]),
        ] else
          source,
    ]));
  }

  void _save(Pool pool) => ref.read(poolsProvider.notifier).save(pool);

  Future<void> _rename() => renamePool(context, ref, _pool);

  /// The tag being assigned in bulk, the cards that had it, and the cards
  /// that will have it once applied.
  String? _taggingTag;
  Set<String> _taggingBefore = const {};
  Set<String> _taggingNow = {};

  Future<void> _newTag() async {
    final name = await newPoolTag(context, ref, _pool);
    if (name != null) _startTagging(name, const []);
  }

  void _startTagging(String tag, Iterable<String> ids) => setState(() {
        _taggingTag = tag;
        _taggingBefore = ids.toSet();
        _taggingNow = ids.toSet();
      });

  void _stopTagging({required bool apply}) {
    final tag = _taggingTag;
    if (apply && tag != null) _save(_withTagCards(_pool, tag, _taggingNow));
    setState(() {
      _taggingTag = null;
      _taggingBefore = const {};
      _taggingNow = {};
    });
  }

  Pool _withTagCards(Pool pool, String tag, Set<String> cardIds) => pool.withTag(tag, cardIds);

  List<String> _visibleTags(PlayPool play) => play.tagNames;

  void _toggleTagging(CardData card) => setState(() {
        _taggingNow.contains(card.id) ? _taggingNow.remove(card.id) : _taggingNow.add(card.id);
      });

  /// Green: added, red: removed, blue: kept, grey: not tagged.
  Color? _taggingTint(CardData card) {
    if (_taggingTag == null) return null;
    final was = _taggingBefore.contains(card.id);
    final now = _taggingNow.contains(card.id);
    return switch ((was, now)) {
      (false, true) => Colors.green,
      (true, false) => Colors.red,
      (true, true) => Colors.blue,
      (false, false) => Colors.grey,
    };
  }

  /// The gallery's selected cards, by id.
  final Set<String> _selected = {};

  /// Scrolls the card list; the selection rectangle follows it.
  final _scroll = ScrollController();

  /// The selection a rectangle adds to: the one before it with Ctrl or
  /// Shift held, else none.
  Set<String> _marqueeBase = const {};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _marqueeStart(bool additive) {
    _marqueeBase = additive ? {..._selected} : const {};
    // No card preview pops up under a rectangle being drawn.
    ref.read(hoverPreviewSuppressedProvider.notifier).set(true);
  }

  void _marqueeEnd() => ref.read(hoverPreviewSuppressedProvider.notifier).set(false);

  void _marqueeHits(Set<String> ids) => setState(() => _selected
    ..clear()
    ..addAll(_marqueeBase)
    ..addAll(ids));

  /// A click the rectangle took: on a card it selects it or not, as a tap
  /// does; on empty space it clears the selection.
  void _marqueeClick(String? id) => setState(() {
        if (id == null) {
          _selected.clear();
        } else {
          _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
        }
      });

  /// The cards the pool shows now (searched and filtered), for "select all".
  List<CardData> _shown = const [];

  /// What the View chip reads: the sort, the grouping and the filters on,
  /// each named ("Sort by Name · Group by Level / Rank, then ATK").
  String _viewSummary(AppLocalizations l10n) => [
        '${l10n.sortBy} ${sortLabel(l10n, _sort)}',
        if (_groupBy != GroupBy.none)
          [
            '${l10n.groupBy} ${_groupName(l10n, _groupBy, _groupQuality)}',
            if (_groupBy2 != GroupBy.none) '${l10n.thenBy.toLowerCase()} ${_groupName(l10n, _groupBy2, _groupQuality2)}',
          ].join(', '),
        if (!_filter.isEmpty) l10n.filtersCount(_filter.activeCount),
      ].join(' · ');

  /// Sort, grouping and filters in one dialog; the page follows each
  /// change as it is made.
  Future<void> _showViewOptions(List<CardWithInfo> allItems) {
    final pool = _pool;
    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final l10n = AppLocalizations.of(context);
          void both(VoidCallback change) {
            setState(change);
            setDialog(() {});
          }

          Widget row(String label, Widget field) => Row(
                children: [
                  SizedBox(width: 96, child: Text(label)),
                  Expanded(child: field),
                ],
              );
          return AlertDialog(
            title: Text(l10n.viewOptions),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row(
                  l10n.sortBy,
                  DropdownButton<CardSort>(
                    key: const Key('sortBy'),
                    isExpanded: true,
                    value: _sort,
                    items: [
                      for (final sort in CardSort.forGame(pool.game))
                        DropdownMenuItem(value: sort, child: Text(sortLabel(l10n, sort))),
                    ],
                    onChanged: (sort) => both(() => _sort = sort!),
                  ),
                ),
                row(
                  l10n.groupBy,
                  DropdownButton<GroupBy>(
                    key: const Key('groupBy'),
                    isExpanded: true,
                    value: _groupBy,
                    items: [
                      for (final group in GroupBy.forGame(pool.game))
                        DropdownMenuItem(
                            value: group,
                            child: Text(group == _groupBy ? _groupName(l10n, group, _groupQuality) : groupLabel(l10n, group))),
                    ],
                    onChanged: (group) async {
                      await _selectGroup(group!);
                      setDialog(() {});
                    },
                  ),
                ),
                if (_groupBy != GroupBy.none)
                  row(
                    l10n.thenBy,
                    DropdownButton<GroupBy>(
                      key: const Key('thenBy'),
                      isExpanded: true,
                      value: _groupBy2,
                      items: [
                        for (final group in GroupBy.forGame(pool.game))
                          if (group != _groupBy)
                            DropdownMenuItem(
                                value: group,
                                child: Text(
                                    group == _groupBy2 ? _groupName(l10n, group, _groupQuality2) : groupLabel(l10n, group))),
                      ],
                      onChanged: (group) async {
                        await _selectGroup2(group!);
                        setDialog(() {});
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('viewFilters'),
                    icon: Badge(
                      isLabelVisible: !_filter.isEmpty,
                      label: Text('${_filter.activeCount}'),
                      child: const Icon(Icons.filter_list),
                    ),
                    label: Text(l10n.filters),
                    onPressed: () => showFilterSheet(
                      context,
                      game: pool.game,
                      items: allItems,
                      filter: _filter,
                      onChanged: (filter) => both(() => _filter = filter),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('viewClose'),
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The cards per row and the size and spacing sliders of the gallery.
  Future<void> _showSizeOptions() => showDialog<void>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.sizeOptions),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GalleryColumnsControl(settingKey: 'pool'),
                SizedBox(height: 8),
                GallerySizeControls(settingKey: 'pool'),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('sizeClose'),
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      );

  void _toggleSelected(CardData card) => setState(() {
        _selected.contains(card.id) ? _selected.remove(card.id) : _selected.add(card.id);
      });

  /// Opens, at [position], the operations on the selected cards. A card
  /// outside the selection becomes the selection first.
  Future<void> _selectionMenu(CardData card, Offset position) async {
    final l10n = AppLocalizations.of(context);
    if (!_selected.contains(card.id)) {
      setState(() => _selected
        ..clear()
        ..add(card.id));
    }
    final play = widget.pool;
    final cards = [for (final e in play.entries) if (_selected.contains(e.card.id)) e.card];
    if (cards.isEmpty) return;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final operation = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(position & Size.zero, Offset.zero & overlay.size),
      items: [
        PopupMenuItem(enabled: false, height: 32, child: Text(l10n.selectedCount(cards.length))),
        const PopupMenuDivider(),
        PopupMenuItem(
          key: const Key('selectionCopies'),
          value: 'copies',
          child: ListTile(leading: const Icon(Icons.filter_none), title: Text(l10n.selectionCopies)),
        ),
        PopupMenuItem(
          key: const Key('selectionTags'),
          value: 'tags',
          child: ListTile(leading: const Icon(Icons.label_outline), title: Text(l10n.selectionTags)),
        ),
        if (cards.length == 1)
          PopupMenuItem(
            key: const Key('selectionDetails'),
            value: 'details',
            child: ListTile(leading: const Icon(Icons.info_outline), title: Text(l10n.selectionDetails)),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          key: const Key('selectionAll'),
          value: 'all',
          child: ListTile(leading: const Icon(Icons.select_all), title: Text(l10n.selectionAll)),
        ),
        PopupMenuItem(
          key: const Key('selectionClear'),
          value: 'clear',
          child: ListTile(leading: const Icon(Icons.deselect), title: Text(l10n.selectionClear)),
        ),
      ],
    );
    if (!mounted) return;
    switch (operation) {
      case 'copies':
        final listed = {for (final e in play.entries) e.card.id: e.listed};
        final picked =
            await pickCopies(context, _pool.copiesOf(cards.first.id, listed: listed[cards.first.id] ?? 1));
        if (picked == null) return;
        // Every card in one save, on the pool as it is now.
        var config = _pool.config;
        for (final c in cards) {
          config = config.withCard(c.id, picked.copies, listed: listed[c.id] ?? 1);
        }
        _save(_pool.copyWith(config: config));
      case 'tags':
        await _editCardsTags(cards);
      case 'details':
        await showCardDetails(context, cards.single, poolId: _pool.id);
      case 'all':
        setState(() => _selected.addAll(_shown.map((c) => c.id)));
      case 'clear':
        setState(_selected.clear);
    }
  }

  /// Picks the user tags of one card with checkboxes.
  Future<void> _editCardTags(CardData card) => _editCardsTags([card]);

  /// Picks the user tags of [cards] with checkboxes: checked are the tags
  /// they all have, and only the tags whose box changed are given to or
  /// taken from every one of them.
  Future<void> _editCardsTags(List<CardData> cards) async {
    final l10n = AppLocalizations.of(context);
    final pool = _pool;
    if (pool.tags.isEmpty) {
      await _newTag();
      return;
    }
    final play = widget.pool;
    final all = _visibleTags(play);
    final cardIds = {for (final c in cards) c.id};
    final chosen = {
      for (final tag in all)
        if ({for (final c in play.tagCards[tag] ?? const <CardData>[]) c.id}.containsAll(cardIds)) tag,
    };
    final before = {...chosen};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(cards.length == 1 ? l10n.cardTags : '${l10n.poolTags} · ${l10n.selectedCount(cards.length)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tags: any number of them. Qualities: one value, or none.
                if (pool.plainTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(l10n.poolTags, style: Theme.of(context).textTheme.labelLarge),
                  ),
                for (final tag in pool.plainTags)
                  CheckboxListTile(
                    dense: true,
                    value: chosen.contains(tag),
                    title: Text(tagLabel(l10n, tag)),
                    onChanged: (on) => setState(() => on == true ? chosen.add(tag) : chosen.remove(tag)),
                  ),
                for (final quality in pool.qualities) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(qualityLabel(l10n, quality), style: Theme.of(context).textTheme.labelLarge),
                  ),
                  RadioGroup<String>(
                    groupValue: chosen.where((t) => Pool.qualityOf(t) == quality).firstOrNull,
                    onChanged: (value) => setState(() {
                      chosen.removeAll(pool.valuesOf(quality));
                      if (value != null) chosen.add(value);
                    }),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final tag in pool.orderedValuesOf(quality))
                          RadioListTile<String>(
                            dense: true,
                            value: tag,
                            toggleable: true,
                            secondary: ColorDot(valueColor(pool, tag), size: 14),
                            title: Text(tagLabel(l10n, tag.substring(quality.length + 1))),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, chosen), child: Text(l10n.apply)),
          ],
        ),
      ),
    );
    if (result == null) return;
    var updated = pool;
    for (final tag in all) {
      if (result.contains(tag) == before.contains(tag)) continue;
      final ids = {for (final c in play.tagCards[tag] ?? const <CardData>[]) c.id};
      result.contains(tag) ? ids.addAll(cardIds) : ids.removeAll(cardIds);
      updated = _withTagCards(updated, tag, ids);
    }
    _save(updated);
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = dataLanguage(ref, context);
    final play = widget.pool;
    final pool = _pool;
    final config = pool.config;

    final infoState = ref.watch(poolCardInfoProvider(pool.id)).value;
    final infos = infoState?.infos ?? const <String, CardInfo>{};
    _fetchMissing(infoState, [for (final e in play.entries) e.card], language);
    final missing = play.entries.where((e) => !infos.containsKey(e.card.id)).length;

    final query = _query.trim().toLowerCase();
    final allItems = [
      for (final e in play.entries)
        (card: e.card, info: infos[e.card.id], tags: play.tagsOfCard(e.card.id)),
    ];
    final shownNames = {for (final e in play.entries) e.card.id: shownName(ref, e.card, language)};
    String nameOf(CardData card) => shownNames[card.id] ?? card.nameFor(language);
    final items = allItems
        .where((item) =>
            query.isEmpty ||
            item.card.id.toLowerCase().contains(query) ||
            item.card.names.values.any((n) => n.toLowerCase().contains(query)) ||
            nameOf(item.card).toLowerCase().contains(query) ||
            (item.info?.name.toLowerCase().contains(query) ?? false))
        .where(_filter.matches)
        .toList()
      ..sort((a, b) => _sort.compare(a, b, language, nameOf: nameOf));
    _shown = [for (final item in items) item.card];
    final listed = {for (final e in play.entries) e.card.id: e.listed};
    final view = ref.watch(poolViewProvider);
    final tagging = _taggingTag != null;
    final actions = PoolCardActions(
      copiesOf: (card) => pool.copiesOf(card.id, listed: listed[card.id] ?? 1),
      listedOf: (card) => listed[card.id] ?? 1,
      changed: (card) => config.overrides.containsKey(card.id),
      setCopies: (card, copies) =>
          _save(pool.copyWith(config: config.withCard(card.id, copies, listed: listed[card.id] ?? 1))),
      tint: _taggingTint,
      onTap: tagging ? _toggleTagging : null,
      draggable: _baskets,
      onTags: _editCardTags,
      selected: (card) => _selected.contains(card.id),
      onSelect: _toggleSelected,
      onMenu: _selectionMenu,
      tagsOf: (card) => [
        for (final tag in play.tagsOfCard(card.id))
          if (!tag.startsWith('rarity:')) tagLabel(l10n, tag),
      ],
    );

    // The kind of a Yu-Gi-Oh! card follows the setting as it changes.
    ref.watch(ygoSplitNormalEffectProvider);
    final header = <Widget>[
      if (_taggingTag case final tag?)
        _Section(
          title: l10n.poolTags,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.taggingTitle(tag), style: theme.textTheme.titleSmall),
              Text(l10n.taggingHint, style: theme.textTheme.bodySmall),
              Row(
                children: [
                  TextButton(onPressed: () => _stopTagging(apply: false), child: Text(l10n.cancel)),
                  FilledButton(onPressed: () => _stopTagging(apply: true), child: Text(l10n.apply)),
                ],
              ),
            ],
          ),
        ),
      if (infoState != null && (missing > 0 || infoState.fetching))
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              if (infoState.fetching) ...[
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.fetchingCardData, style: theme.textTheme.bodySmall)),
              ] else ...[
                Expanded(
                  child: Text(
                    infoState.failed ? l10n.fetchCardDataFailed : l10n.cardDataMissing(missing),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: Text(l10n.fetchCardData),
                  onPressed: () {
                    _fetchedFor = null;
                    ref.read(poolCardInfoProvider(pool.id).notifier).fetchMissing(
                        pool.game, [for (final e in play.entries) e.card],
                        language: language);
                  },
                ),
              ],
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(l10n.cardsShown(items.length, allItems.length), style: theme.textTheme.labelMedium),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<PoolView>(
          showSelectedIcon: false,
          segments: [
            for (final (view, icon, label) in [
              (PoolView.list, Icons.view_list, l10n.viewList),
              (PoolView.gallery, Icons.grid_view, l10n.viewGallery),
              (PoolView.stacks, Icons.view_column, l10n.viewStacks),
              (PoolView.spoiler, Icons.article, l10n.viewSpoiler),
            ])
              ButtonSegment(value: view, icon: Icon(icon), label: Text(label)),
          ],
          selected: {view},
          onSelectionChanged: (selection) => ref.read(poolViewProvider.notifier).select(selection.single),
        ),
            ActionChip(
              key: const Key('viewChip'),
              avatar: Badge(
                isLabelVisible: !_filter.isEmpty,
                label: Text('${_filter.activeCount}'),
                child: const Icon(Icons.tune, size: 18),
              ),
              label: Text(_viewSummary(l10n)),
              tooltip: l10n.viewOptions,
              onPressed: () => _showViewOptions(allItems),
            ),
            if (view == PoolView.gallery)
              IconButton(
                key: const Key('sizeOptions'),
                tooltip: l10n.sizeOptions,
                icon: const Icon(Icons.photo_size_select_large),
                onPressed: _showSizeOptions,
              ),
            IconButton(
              tooltip: l10n.poolStats,
              icon: const Icon(Icons.bar_chart),
              onPressed: () => showMetricsSheet(context, game: pool.game, items: items),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: SearchBar(
          leading: const Icon(Icons.search),
          hintText: l10n.searchCards,
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: InkWell(onTap: _rename, child: Text(pool.name)),
        actions: [
          IconButton(
            key: const Key('tierlistButton'),
            tooltip: l10n.tierlist,
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => context.push(poolModePath(pool.game, pool.id, 'tierlist')),
          ),
          IconButton(
            key: const Key('basketsToggle'),
            tooltip: l10n.tagBaskets,
            isSelected: _baskets,
            icon: const Icon(Icons.shopping_basket_outlined),
            selectedIcon: const Icon(Icons.shopping_basket),
            onPressed: () => setState(() => _baskets = !_baskets),
          ),
          if (ref.watch(cardSearchProvider) != null)
            IconButton(
              key: const Key('searchPanelToggle'),
              tooltip: l10n.searchPanel,
              isSelected: _searchOpen,
              icon: const Icon(Icons.add),
              selectedIcon: const Icon(Icons.playlist_add_check),
              onPressed: () => setState(() => _searchOpen = !_searchOpen),
            ),
          IconButton(
            tooltip: l10n.poolDetails,
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(poolModePath(pool.game, pool.id, 'details')),
          ),
          if (config.overrides.isNotEmpty)
            IconButton(
              tooltip: l10n.resetCards,
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _save(pool.copyWith(config: config.withoutOverrides())),
            ),
        ],
      ),
      body: _withSearchPanel(
        play,
        _withBaskets(play, MarqueeSelection(
        controller: _scroll,
        // The selection, in every view; bulk tagging and baskets keep the mouse.
        enabled: !tagging && !_baskets,
        onStart: _marqueeStart,
        onHits: _marqueeHits,
        onClick: _marqueeClick,
        onEnd: _marqueeEnd,
        child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverList.list(children: header),
          if (view == PoolView.stacks && (_groupBy == GroupBy.none || _groupBy2 == GroupBy.none))
            PoolStacksSliver(
              items: items,
              actions: actions,
              labelOf: (item) => _groupBy == GroupBy.none
                  ? [stackLabel(_sort, item, language, nameOf: nameOf)]
                  : _groupBy.labelsOf(item, language, quality: _groupQuality),
              header: (label) => _groupBy == GroupBy.none
                  ? valueLabel(l10n, label)
                  : groupHeader(l10n, _groupBy, label),
            )
          else if (view == PoolView.stacks)
            // Grouped twice: a foldable row of stacks per primary group,
            // its stacks split by the secondary grouping.
            for (final (label, group) in _grouped(items, language, _groupBy, _groupQuality)) ...[
              _groupHeader(
                key: label!,
                title: '${groupHeader(l10n, _groupBy, label)} · ${group.length}',
                theme: theme,
                level: 0,
              ),
              if (!_collapsed.contains(label))
                PoolStacksSliver(
                  key: ValueKey('stacks-$label'),
                  items: group,
                  actions: actions,
                  labelOf: (item) => _groupBy2.labelsOf(item, language, quality: _groupQuality2),
                  header: (sub) => groupHeader(l10n, _groupBy2, sub),
                ),
            ]
          else
            for (final (label, group) in _grouped(items, language, _groupBy, _groupQuality)) ...[
              if (label != null)
                _groupHeader(
                  key: label,
                  title: '${groupHeader(l10n, _groupBy, label)} · ${group.length}',
                  theme: theme,
                  level: 0,
                ),
              if (label == null || !_collapsed.contains(label))
                if (_groupBy2 == GroupBy.none || label == null)
                  _viewSliver(view, group, actions, language, l10n)
                else
                  for (final (sub, subgroup) in _grouped(group, language, _groupBy2, _groupQuality2)) ...[
                    _groupHeader(
                      key: '$label/$sub',
                      title: '${groupHeader(l10n, _groupBy2, sub!)} · ${subgroup.length}',
                      theme: theme,
                      level: 1,
                    ),
                    if (!_collapsed.contains('$label/$sub'))
                      _viewSliver(view, subgroup, actions, language, l10n),
                  ],
            ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ))),
      ),
    );
  }

  /// [cards] alone, or under the tag baskets in basket mode, with Ctrl+Z
  /// undoing the last drop.
  Widget _withBaskets(PlayPool play, Widget cards) {
    if (!_baskets) return cards;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undoDrop,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undoDrop,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l10n.basketsHint, style: theme.textTheme.bodySmall)),
                        TextButton.icon(
                          key: const Key('undoDrop'),
                          icon: const Icon(Icons.undo, size: 18),
                          label: Text(l10n.undo),
                          onPressed: _undo.isEmpty ? null : _undoDrop,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${l10n.poolTags}:', style: theme.textTheme.labelMedium),
                          for (final tag in play.pool.plainTags)
                            _Basket(
                              key: ValueKey('basket-$tag'),
                              label: '${tagLabel(l10n, tag)} · ${play.tagCards[tag]?.length ?? 0}',
                              onDrop: (card) => _dropOnBasket(tag, card),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: Text(l10n.newTag),
                            onPressed: () => newPoolTag(context, ref, _pool),
                          ),
                        ],
                      ),
                    ),
                    for (final quality in play.pool.qualities)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('${qualityLabel(l10n, quality)}:', style: theme.textTheme.labelMedium),
                            for (final tag in play.pool.orderedValuesOf(quality))
                              _Basket(
                                key: ValueKey('basket-$tag'),
                                label: '${tagLabel(l10n, tag.substring(quality.length + 1))}'
                                    ' · ${play.tagCards[tag]?.length ?? 0}',
                                color: valueColor(play.pool, tag),
                                onDrop: (card) => _dropOnBasket(tag, card),
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 18),
                              label: Text(l10n.addValue),
                              onPressed: () => newQualityValue(context, ref, _pool, quality),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: cards),
          ],
        ),
      ),
    );
  }

  /// [poolBody] alone, or with the search panel: beside it on a wide
  /// window, in its place on a narrow one.
  Widget _withSearchPanel(PlayPool play, Widget poolBody) {
    if (!_searchOpen) return poolBody;
    final panel = SearchPanel(
      pool: play,
      onAdd: _addFound,
      onAddBatch: _addBatch,
      onRemove: _removePicked,
      onClose: () => setState(() => _searchOpen = false),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 900) return panel;
      final width = constraints.maxWidth;
      final panelWidth = (width * _panelShare).clamp(300.0, width - 300.0);
      return Row(
        children: [
          Expanded(child: poolBody),
          // The splitter: drag it to resize the panel.
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              key: const Key('panelSplitter'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) => setState(() {
                _panelShare = ((panelWidth - d.delta.dx) / width).clamp(0.2, 0.8);
              }),
              child: SizedBox(
                width: 10,
                child: Center(
                  child: Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: panelWidth, child: panel),
        ],
      );
    });
  }

  /// The listed cards split by [_groupBy], in the order groups first
  /// appear; a single unnamed group without grouping.
  List<(String?, List<CardWithInfo>)> _grouped(
      List<CardWithInfo> items, String language, GroupBy group, String? quality) {
    if (group == GroupBy.none) return [(null, items)];
    final groups = <String, List<CardWithInfo>>{};
    for (final item in items) {
      for (final label in group.labelsOf(item, language, quality: quality)) {
        (groups[label] ??= []).add(item);
      }
    }
    return [for (final MapEntry(:key, :value) in groups.entries) (key, value)];
  }

  /// A foldable section header; [level] 1 is a secondary group, indented.
  Widget _groupHeader({required String key, required String title, required ThemeData theme, required int level}) =>
      SliverToBoxAdapter(
        child: InkWell(
          onTap: () => setState(() {
            _collapsed.contains(key) ? _collapsed.remove(key) : _collapsed.add(key);
          }),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.0 + 24 * level, level == 0 ? 12 : 6, 16, 4),
            child: Row(
              children: [
                Icon(_collapsed.contains(key) ? Icons.expand_more : Icons.expand_less, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: level == 0 ? theme.textTheme.titleSmall : theme.textTheme.labelLarge),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _viewSliver(
    PoolView view,
    List<CardWithInfo> items,
    PoolCardActions actions,
    String language,
    AppLocalizations l10n,
  ) =>
      switch (view) {
            PoolView.list => PoolListSliver(items: items, actions: actions, language: language),
            PoolView.gallery => PoolGallerySliver(
                items: items,
                actions: actions,
                columns: ref.watch(galleryColumnsProvider('pool')),
                cardWidth: ref.watch(galleryCardWidthProvider('pool')),
                spacing: ref.watch(gallerySpacingProvider('pool')),
              ),
            // Stacks are laid out as a whole, see build.
            PoolView.stacks => const SliverToBoxAdapter(child: SizedBox.shrink()),
            PoolView.spoiler => PoolSpoilerSliver(items: items, actions: actions, language: language),
          };
}

/// A tag's basket: drop a card on it to give it the tag. A value's basket
/// wears its color.
class _Basket extends StatelessWidget {
  const _Basket({super.key, required this.label, required this.onDrop, this.color});

  final String label;
  final Color? color;
  final void Function(CardData card) onDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<CardData>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, rejected) {
        final hovered = candidates.isNotEmpty;
        final tint = color ?? theme.colorScheme.primary;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hovered
                ? tint.withValues(alpha: 0.45)
                : color?.withValues(alpha: 0.18) ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered ? tint : color ?? theme.colorScheme.outlineVariant,
              width: hovered ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(hovered ? Icons.shopping_basket : Icons.shopping_basket_outlined, size: 18),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
}

