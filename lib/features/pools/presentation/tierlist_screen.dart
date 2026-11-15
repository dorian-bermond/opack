import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../card_info/data/card_info_repository.dart';
import '../../card_info/domain/card_filter.dart';
import '../../card_info/domain/card_info.dart';
import '../../card_info/presentation/filter_sheet.dart';
import '../../card_info/presentation/labels.dart';
import '../../catalog/domain/models.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_actions.dart';
import 'pool_loader.dart';
import 'pool_view.dart';

/// Tierlist mode: gives cards a value of one quality by dragging them.
/// A quality is chosen, then a group of cards (every card, a tag, or a
/// filter); the cards of the group holding a value of the quality sit in
/// one tier per value, the others in a feed at the bottom. Cards drag from
/// the feed to a tier, from tier to tier, or back to the feed to lose
/// their value; Ctrl+Z undoes the last drop.
class TierlistScreen extends StatelessWidget {
  const TierlistScreen({super.key, required this.poolId, this.quality, this.tag});

  final String poolId;

  /// The quality to start on, else the pool's first one.
  final String? quality;

  /// The tag to start on, else every card.
  final String? tag;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => _Tierlist(pool: pool, quality: quality, tag: tag),
      );
}

class _Tierlist extends ConsumerStatefulWidget {
  const _Tierlist({required this.pool, this.quality, this.tag});

  final PlayPool pool;
  final String? quality;
  final String? tag;

  @override
  ConsumerState<_Tierlist> createState() => _TierlistState();
}

class _TierlistState extends ConsumerState<_Tierlist> {
  String? _quality;

  /// The tag the group is taken from, `null` for every card.
  String? _tag;
  CardFilter _filter = const CardFilter();

  /// The pools before each drop, newest last.
  final List<Pool> _undo = [];

  Pool get _pool => widget.pool.pool;

  @override
  void initState() {
    super.initState();
    _quality = widget.quality ?? _pool.qualities.firstOrNull;
    _tag = widget.tag;
  }

  void _save(Pool pool) => savePool(ref, pool);

  /// The tiers of the chosen quality: its tags, in the pool's order.
  List<String> get _tiers => [
        for (final tag in _pool.tags.keys)
          if (Pool.qualityOf(tag) == _quality) tag,
      ];

  /// Puts [card] in [tier] right before [before], or last; its other
  /// value of the quality goes.
  void _dropOnTier(String tier, CardData card, {String? before}) {
    final cards = [for (final c in widget.pool.tagCards[tier] ?? const <CardData>[]) c.id];
    final at = before == null ? cards.length : cards.indexOf(before);
    if (cards.indexOf(card.id) case final i when i >= 0 && (i == at || i + 1 == at)) return;
    setState(() => _undo.add(_pool));
    _save(_pool.withCardInTag(tier, card.id, before: before));
  }

  /// Moves [tier] one rank up ([by] -1) or down (+1) among its quality's
  /// values.
  void _moveTier(String tier, int by) {
    final tiers = _tiers;
    final i = tiers.indexOf(tier);
    final j = i + by;
    if (i < 0 || j < 0 || j >= tiers.length) return;
    setState(() => _undo.add(_pool));
    _save(_pool.withTagBefore(tier, by < 0 ? tiers[j] : (j + 1 < tiers.length ? tiers[j + 1] : null)));
  }

  /// Takes [card] out of its tier, back to the feed.
  void _dropOnFeed(CardData card) {
    final tier = _tiers.where((t) => (widget.pool.tagCards[t] ?? const []).any((c) => c.id == card.id)).firstOrNull;
    if (tier == null) return;
    setState(() => _undo.add(_pool));
    _save(_pool.withTag(tier, [
      for (final c in widget.pool.tagCards[tier]!) if (c.id != card.id) c.id,
    ]));
  }

  void _undoDrop() {
    if (_undo.isEmpty) return;
    final previous = _undo.removeLast();
    setState(() {});
    _save(previous.copyWith());
  }

  Future<void> _addTier() async {
    final quality = _quality;
    if (quality == null) return;
    await newPoolTag(context, ref, _pool, quality: quality);
  }

  /// Picks a quality, or makes a new one through the new tag dialog.
  Future<void> _pickQuality() async {
    final l10n = AppLocalizations.of(context);
    final qualities = _pool.qualities;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(l10n.tierlistQuality, style: Theme.of(context).textTheme.titleMedium)),
            for (final quality in qualities)
              ListTile(
                leading: Icon(quality == _quality ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(qualityLabel(l10n, quality)),
                onTap: () => Navigator.pop(context, quality),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.newQuality),
              onTap: () => Navigator.pop(context, ''),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    if (chosen.isNotEmpty) return setState(() => _quality = chosen);
    final quality = await newPoolQuality(context, ref, _pool);
    if (quality != null) setState(() => _quality = quality);
  }

  Future<void> _pickTag() async {
    final l10n = AppLocalizations.of(context);
    final tags = [for (final tag in _pool.tags.keys) if (Pool.qualityOf(tag) != _quality) tag];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(l10n.tierlistGroup, style: Theme.of(context).textTheme.titleMedium)),
            ListTile(
              leading: Icon(_tag == null ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(l10n.allCards),
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final tag in tags)
              ListTile(
                leading: Icon(tag == _tag ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(tagLabel(l10n, tag)),
                onTap: () => Navigator.pop(context, tag),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _tag = chosen.isEmpty ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final play = widget.pool;
    final quality = _quality;
    final infos = ref.watch(poolCardInfoProvider(_pool.id)).value?.infos ?? const <String, CardInfo>{};

    final allItems = [
      for (final e in play.entries) (card: e.card, info: infos[e.card.id], tags: play.tagsOfCard(e.card.id)),
    ];
    final inTag = _tag == null ? null : {for (final c in play.tagCards[_tag] ?? const <CardData>[]) c.id};
    final group = [
      for (final item in allItems)
        if ((inTag == null || inTag.contains(item.card.id)) && _filter.matches(item)) item,
    ];
    final tiers = _tiers;
    // A tier's cards in the tag's order: their rank within the value.
    final groupIds = {for (final item in group) item.card.id};
    final valued = <String, List<CardData>>{
      for (final tier in tiers)
        tier: [
          for (final card in play.tagCards[tier] ?? const <CardData>[])
            if (groupIds.contains(card.id)) card,
        ],
    };
    final placed = {for (final cards in valued.values) for (final c in cards) c.id};
    final feed = [for (final item in group) if (!placed.contains(item.card.id)) item.card];

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.tierlist} · ${_pool.name}'),
        actions: [
          IconButton(
            key: const Key('tierlistUndo'),
            tooltip: l10n.undo,
            icon: const Icon(Icons.undo),
            onPressed: _undo.isEmpty ? null : _undoDrop,
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undoDrop,
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undoDrop,
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      key: const Key('tierlistQuality'),
                      avatar: const Icon(Icons.category_outlined, size: 18),
                      label: Text(
                          '${l10n.tierlistQuality}: ${quality == null ? l10n.noQualityYet : qualityLabel(l10n, quality)}'),
                      onPressed: _pickQuality,
                    ),
                    ActionChip(
                      key: const Key('tierlistGroup'),
                      avatar: const Icon(Icons.label_outline, size: 18),
                      label: Text('${l10n.tierlistGroup}: ${_tag == null ? l10n.allCards : tagLabel(l10n, _tag!)}'),
                      onPressed: _pickTag,
                    ),
                    ActionChip(
                      avatar: Badge(
                        isLabelVisible: !_filter.isEmpty,
                        label: Text('${_filter.activeCount}'),
                        child: const Icon(Icons.filter_list, size: 18),
                      ),
                      label: Text(l10n.filters),
                      onPressed: () => showFilterSheet(
                        context,
                        game: _pool.game,
                        items: allItems,
                        filter: _filter,
                        onChanged: (filter) => setState(() => _filter = filter),
                      ),
                    ),
                    Text(l10n.cardsCount(group.length), style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              Expanded(
                child: quality == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.tierlistNoQuality, textAlign: TextAlign.center),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        children: [
                          for (final (i, tier) in tiers.indexed)
                            _Tier(
                              key: ValueKey('tier-$tier'),
                              label: tagLabel(l10n, tier.substring(quality.length + 1)),
                              cards: valued[tier]!,
                              onDrop: (card, {before}) => _dropOnTier(tier, card, before: before),
                              onMoveUp: i == 0 ? null : () => _moveTier(tier, -1),
                              onMoveDown: i == tiers.length - 1 ? null : () => _moveTier(tier, 1),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const Key('addTier'),
                                icon: const Icon(Icons.add),
                                label: Text(l10n.addTier),
                                onPressed: _addTier,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (quality != null)
                _Feed(cards: feed, hint: l10n.tierlistFeedHint, onDrop: _dropOnFeed),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tier: its label and rank arrows, then its cards in a row that
/// scrolls sideways, ranked left to right. A drop target for cards of the
/// feed or of other tiers; dropping on a card ranks before it, on the
/// row's free space last.
class _Tier extends StatelessWidget {
  const _Tier({
    super.key,
    required this.label,
    required this.cards,
    required this.onDrop,
    this.onMoveUp,
    this.onMoveDown,
  });

  final String label;
  final List<CardData> cards;
  final void Function(CardData card, {String? before}) onDrop;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<CardData>(
      onWillAcceptWithDetails: (d) => cards.lastOrNull?.id != d.data.id,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final hovered = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: hovered ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: hovered ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
                      Text('${cards.length}', style: theme.textTheme.labelMedium),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('tierUp-$label'),
                            icon: const Icon(Icons.arrow_upward, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: onMoveUp,
                          ),
                          IconButton(
                            key: ValueKey('tierDown-$label'),
                            icon: const Icon(Icons.arrow_downward, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: onMoveDown,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _RankedCard(
                      card: cards[i],
                      onDropBefore: (card) => onDrop(card, before: cards[i].id),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A card of a tier: dragged to rank it elsewhere, and a drop target that
/// ranks the dropped card right before it.
class _RankedCard extends StatelessWidget {
  const _RankedCard({required this.card, required this.onDropBefore});

  final CardData card;
  final void Function(CardData card) onDropBefore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<CardData>(
      onWillAcceptWithDetails: (d) => d.data.id != card.id,
      onAcceptWithDetails: (d) => onDropBefore(d.data),
      builder: (context, candidates, _) => Container(
        width: 96,
        decoration: candidates.isEmpty
            ? null
            : BoxDecoration(border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3))),
        child: DraggableCard(card: card, enabled: true, child: CardTile(card: card)),
      ),
    );
  }
}

/// The cards of the group without a value yet, scrolled sideways; a
/// drop target that takes a card's value away.
class _Feed extends StatelessWidget {
  const _Feed({required this.cards, required this.hint, required this.onDrop});

  final List<CardData> cards;
  final String hint;
  final void Function(CardData card) onDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<CardData>(
      onWillAcceptWithDetails: (d) => !cards.any((c) => c.id == d.data.id),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final hovered = candidates.isNotEmpty;
        return Material(
          key: const Key('tierlistFeed'),
          color: hovered ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text('$hint · ${cards.length}', style: theme.textTheme.labelMedium),
                ),
                SizedBox(
                  height: 166,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => SizedBox(
                      width: 108,
                      child: DraggableCard(card: cards[i], enabled: true, child: CardTile(card: cards[i])),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
