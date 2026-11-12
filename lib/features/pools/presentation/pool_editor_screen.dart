import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/images/card_image_cache.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../card_info/data/card_info_repository.dart';
import '../../card_info/domain/card_filter.dart';
import '../../card_info/domain/card_info.dart';
import '../../card_info/presentation/card_search_sheet.dart';
import '../../card_info/presentation/filter_sheet.dart';
import '../../card_info/presentation/labels.dart';
import '../../card_info/presentation/metrics_sheet.dart';
import '../../card_text/presentation/card_details_sheet.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../../cube/data/cube_repository.dart';
import '../data/pool_repository.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_composition_screen.dart';
import 'pool_loader.dart';
import 'pool_view.dart';
import 'pool_widgets.dart';
import 'source_picker.dart';

/// Edits a saved pool: its name, sources, pack layout and the copies of
/// each card.
class PoolEditorScreen extends StatelessWidget {
  const PoolEditorScreen({super.key, required this.poolId});

  final String poolId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => _PoolEditor(pool: pool),
      );
}

class _PoolEditor extends ConsumerStatefulWidget {
  const _PoolEditor({required this.pool});

  final PlayPool pool;

  @override
  ConsumerState<_PoolEditor> createState() => _PoolEditorState();
}

class _PoolEditorState extends ConsumerState<_PoolEditor> {
  String _query = '';
  CardSort _sort = CardSort.rarity;
  GroupBy _groupBy = GroupBy.none;

  /// A second grouping inside each primary group.
  GroupBy _groupBy2 = GroupBy.none;

  /// Group labels folded away by the user.
  final Set<String> _collapsed = {};
  CardFilter _filter = const CardFilter();

  /// Which card list a download was already asked for, so it runs once.
  String? _fetchedFor;

  Pool get _pool => widget.pool.pool;

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

  /// Searches cards online and adds the chosen ones as picked cards, with
  /// their details.
  Future<void> _addCards() async {
    final pool = _pool;
    final picked = pool.sources.whereType<CardsSource>().firstOrNull ?? const CardsSource([]);
    final found = await showCardSearch(
      context,
      game: pool.game,
      excludeIds: {for (final e in widget.pool.entries) e.card.id},
    );
    if (found == null || found.isEmpty) return;
    _save(pool.copyWith(sources: [
      for (final source in pool.sources)
        if (source is! CardsSource) source,
      picked.plus(found.map((f) => f.card)),
    ]));
    await ref
        .read(poolCardInfoProvider(pool.id).notifier)
        .addInfos({for (final f in found) f.card.id: f.info});
  }

  void _save(Pool pool) => ref.read(poolsProvider.notifier).save(pool);

  Future<void> _rename() async {
    final name = await _askName(AppLocalizations.of(context).renamePool, initial: _pool.name);
    if (name != null) _save(_pool.copyWith(name: name));
  }

  /// Adds a set or a cube; its cards join the tags the pool already has
  /// (rarities, all cards, and the set's own sheet names).
  Future<void> _addSource() async {
    final pool = _pool;
    final source = await pickPoolSource(context, game: pool.game, exclude: pool.sources);
    if (source == null) return;
    final existing = widget.pool.entries.map((e) => e.card);
    switch (source) {
      case SetSource(:final code):
        final set = await ref.read(catalogRepositoryProvider).loadSet(pool.game, code);
        _save(pool.withSource(source, cards: set.cards, existing: existing, set: set));
      case CubeSource(:final id):
        final cube = (await ref.read(cubesProvider.future)).where((c) => c.id == id).firstOrNull;
        _save(pool.withSource(source, cards: cube?.cards ?? const [], existing: existing));
      case CardsSource(:final cards):
        _save(pool.withSource(source, cards: cards, existing: existing));
    }
  }

  /// The tag being assigned in bulk, the cards that had it, and the cards
  /// that will have it once applied.
  String? _taggingTag;
  Set<String> _taggingBefore = const {};
  Set<String> _taggingNow = {};

  Future<String?> _askName(String title, {String initial = '', String? label}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(title: title, initial: initial, label: label),
    );
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _newTag() async {
    final l10n = AppLocalizations.of(context);
    final name = await _askName(l10n.newTag, label: l10n.tagName);
    if (name == null || _pool.tags.containsKey(name)) return;
    _save(_pool.withTag(name, const []));
    _startTagging(name, const []);
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

  /// Deletes [tag] after a warning listing the slots pulling from it; they
  /// lose that option, and go when nothing is left.
  Future<void> _deleteTag(PlayPool play, String tag) async {
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
    _save(pool.withoutTag(tag));
  }

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

  /// Picks the user tags of one card with checkboxes.
  Future<void> _editCardTags(CardData card) async {
    final l10n = AppLocalizations.of(context);
    final pool = _pool;
    if (pool.tags.isEmpty) {
      await _newTag();
      return;
    }
    final play = widget.pool;
    final all = _visibleTags(play);
    final chosen = {
      for (final tag in all)
        if ((play.tagCards[tag] ?? const []).any((c) => c.id == card.id)) tag,
    };
    final before = {...chosen};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.cardTags),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final tag in all)
                  CheckboxListTile(
                    dense: true,
                    value: chosen.contains(tag),
                    title: Text(tagLabel(l10n, tag)),
                    onChanged: (on) => setState(() => on == true ? chosen.add(tag) : chosen.remove(tag)),
                  ),
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
      result.contains(tag) ? ids.add(card.id) : ids.remove(card.id);
      updated = _withTagCards(updated, tag, ids);
    }
    _save(updated);
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = dataLanguage(ref, context);
    final uiLanguage = Localizations.localeOf(context).languageCode;
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
    final items = allItems
        .where((item) =>
            query.isEmpty ||
            item.card.id.toLowerCase().contains(query) ||
            item.card.names.values.any((n) => n.toLowerCase().contains(query)) ||
            (item.info?.name.toLowerCase().contains(query) ?? false))
        .where(_filter.matches)
        .toList()
      ..sort((a, b) => _sort.compare(a, b, language));
    final listed = {for (final e in play.entries) e.card.id: e.listed};
    final view = ref.watch(poolViewProvider);
    final tagging = _taggingTag != null;
    final actions = PoolCardActions(
      copiesOf: (card) => config.copiesOf(card.id, listed: listed[card.id] ?? 1),
      listedOf: (card) => listed[card.id] ?? 1,
      changed: (card) => config.overrides.containsKey(card.id),
      setCopies: (card, copies) =>
          _save(pool.copyWith(config: config.withCard(card.id, copies, listed: listed[card.id] ?? 1))),
      tint: _taggingTint,
      onTap: tagging ? _toggleTagging : null,
      onTags: _editCardTags,
      tagsOf: (card) => [
        for (final tag in play.tagsOfCard(card.id))
          if (!tag.startsWith('rarity:')) tagLabel(l10n, tag),
      ],
    );

    final header = <Widget>[
      _Section(
        title: l10n.poolSources,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final source in pool.sources)
              InputChip(
                avatar: Icon(source is SetSource ? Icons.style : Icons.view_module, size: 18),
                label: Text(sourceName(ref, pool.game, source, uiLanguage)),
                onDeleted: () => _save(pool.withoutSource(source)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l10n.addSource),
              onPressed: _addSource,
            ),
            if (ref.watch(cardSearchProvider) != null)
              ActionChip(
                avatar: const Icon(Icons.travel_explore, size: 18),
                label: Text(l10n.addCards),
                onPressed: _addCards,
              ),
          ],
        ),
      ),
      _Section(
        title: l10n.boosterComposition,
        child: Row(
          children: [
            Expanded(
              child: Text(
                pool.slots.isEmpty
                    ? l10n.noUserSlots
                    : [
                        for (final slot in pool.slots) l10n.slotRow(slot.count, slotOptionsLabel(l10n, slot)),
                      ].join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.tune),
              label: Text(l10n.editComposition),
              onPressed: () => context.push(poolModePath(pool.game, pool.id, 'composition')),
            ),
            TextButton.icon(
              icon: const Icon(Icons.sports_esports),
              label: Text(l10n.formats),
              onPressed: () => context.push(poolModePath(pool.game, pool.id, 'formats')),
            ),
          ],
        ),
      ),
      _Section(
        title: l10n.poolTags,
        child: switch (_taggingTag) {
          final tag? => Column(
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
          null => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in _visibleTags(play))
                    InputChip(
                      avatar: const Icon(Icons.label_outline, size: 18),
                      label: Text('${tagLabel(l10n, name)} · ${play.tagCards[name]?.length ?? 0}'),
                      tooltip: l10n.tagCardsAction,
                      onPressed: () =>
                          _startTagging(name, (play.tagCards[name] ?? const []).map((c) => c.id)),
                      onDeleted: () => _deleteTag(play, name),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(l10n.newTag),
                    onPressed: _newTag,
                  ),
                ],
              ),
        },
      ),
      _Section(
        title: l10n.poolCopies,
        child: PresetPicker(config: config, onChanged: (c) => _save(pool.copyWith(config: c))),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(play.summary(l10n), style: theme.textTheme.bodyMedium),
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
        child: SegmentedButton<PoolView>(
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
          PopupMenuButton<CardSort>(
            tooltip: l10n.sortBy,
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              for (final sort in CardSort.forGame(pool.game))
                CheckedPopupMenuItem(value: sort, checked: sort == _sort, child: Text(sortLabel(l10n, sort))),
            ],
          ),
          PopupMenuButton<GroupBy>(
            tooltip: l10n.groupBy,
            icon: Icon(_groupBy == GroupBy.none ? Icons.segment : Icons.view_agenda),
            initialValue: _groupBy,
            onSelected: (group) => setState(() {
              _groupBy = group;
              if (group == GroupBy.none || group == _groupBy2) _groupBy2 = GroupBy.none;
            }),
            itemBuilder: (context) => [
              for (final group in GroupBy.forGame(pool.game))
                CheckedPopupMenuItem(
                    value: group, checked: group == _groupBy, child: Text(groupLabel(l10n, group))),
            ],
          ),
          if (_groupBy != GroupBy.none)
            PopupMenuButton<GroupBy>(
              tooltip: l10n.thenBy,
              icon: Icon(_groupBy2 == GroupBy.none ? Icons.subdirectory_arrow_right : Icons.account_tree),
              initialValue: _groupBy2,
              onSelected: (group) => setState(() => _groupBy2 = group),
              itemBuilder: (context) => [
                for (final group in GroupBy.forGame(pool.game))
                  if (group != _groupBy)
                    CheckedPopupMenuItem(
                        value: group, checked: group == _groupBy2, child: Text(groupLabel(l10n, group))),
              ],
            ),
          IconButton(
            tooltip: l10n.filters,
            icon: Badge(
              isLabelVisible: !_filter.isEmpty,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => showFilterSheet(
              context,
              game: pool.game,
              items: allItems,
              filter: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
          ),
          IconButton(
            tooltip: l10n.poolStats,
            icon: const Icon(Icons.bar_chart),
            onPressed: () => showMetricsSheet(context, game: pool.game, items: items),
          ),
          IconButton(tooltip: l10n.renamePool, icon: const Icon(Icons.edit), onPressed: _rename),
          if (config.overrides.isNotEmpty)
            IconButton(
              tooltip: l10n.resetCards,
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _save(pool.copyWith(config: config.withoutOverrides())),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverList.list(children: header),
          if (view == PoolView.stacks)
            PoolStacksSliver(
              items: items,
              actions: actions,
              labelOf: (item) => _groupBy == GroupBy.none
                  ? [stackLabel(_sort, item, language)]
                  : _groupBy.labelsOf(item, language),
              header: (label) => _groupBy == GroupBy.none
                  ? valueLabel(l10n, label)
                  : groupHeader(l10n, _groupBy, label),
            )
          else
            for (final (label, group) in _grouped(items, language, _groupBy)) ...[
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
                  for (final (sub, subgroup) in _grouped(group, language, _groupBy2)) ...[
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
      ),
    );
  }

  /// The listed cards split by [_groupBy], in the order groups first
  /// appear; a single unnamed group without grouping.
  List<(String?, List<CardWithInfo>)> _grouped(List<CardWithInfo> items, String language, GroupBy group) {
    if (group == GroupBy.none) return [(null, items)];
    final groups = <String, List<CardWithInfo>>{};
    for (final item in items) {
      for (final label in group.labelsOf(item, language)) {
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
            PoolView.list => SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final (:card, :info, tags: _) = items[i];
                  final listedTimes = actions.listedOf(card);
                  final tags = actions.tagsOf(card);
                  return ListTile(
                    dense: true,
                    tileColor: actions.tint(card)?.withValues(alpha: 0.18),
                    onTap: actions.onTap == null ? null : () => actions.onTap!(card),
                    onLongPress: () => showCardDetails(context, card),
                    title: Text(
                      card.nameFor(language),
                      style: actions.changed(card) ? const TextStyle(fontWeight: FontWeight.bold) : null,
                    ),
                    subtitle: Text([
                      [
                        card.id,
                        card.rarity.label(l10n),
                        if (listedTimes > 1) l10n.listedTimes(listedTimes),
                        if (tags.isNotEmpty) tags.join(', '),
                      ].join(' · '),
                      ?cardInfoLine(info),
                    ].join('\n')),
                    isThreeLine: info != null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.cardTags,
                          icon: const Icon(Icons.label_outline, size: 20),
                          onPressed: () => actions.onTags(card),
                        ),
                        CopiesDropdown(
                          value: actions.copiesOf(card),
                          onChanged: (value) => actions.setCopies(card, value),
                        ),
                      ],
                    ),
                  );
                },
              ),
            PoolView.gallery => PoolGallerySliver(items: items, actions: actions),
            // Stacks are laid out as a whole, see build.
            PoolView.stacks => const SliverToBoxAdapter(child: SizedBox.shrink()),
            PoolView.spoiler => PoolSpoilerSliver(items: items, actions: actions, language: language),
          };
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

