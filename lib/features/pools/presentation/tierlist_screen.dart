import 'package:flutter/gestures.dart';
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
import '../../card_text/data/card_text_repository.dart';
import '../../catalog/domain/models.dart';
import '../data/pool_repository.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_actions.dart';
import 'pool_loader.dart';
import 'pool_view.dart';
import 'pool_widgets.dart';

/// Tierlist mode: gives cards a value of one quality by dragging them.
/// A quality is chosen, then a group of cards (every card, a tag, or a
/// filter); the cards of the group holding a value of the quality sit in
/// one tier per value, the others in a feed at the bottom. Cards drag from
/// the feed to a tier, from tier to tier, or back to the feed to lose
/// their value; Ctrl+Z undoes the last drop.
/// The width of a card in the tierlist, saved across launches.
final tierlistCardWidthProvider = NotifierProvider<TierlistCardWidth, double>(TierlistCardWidth.new);

class TierlistCardWidth extends Notifier<double> {
  static const _key = 'tierlistCardWidth';
  static const min = 56.0;
  static const max = 220.0;

  @override
  double build() => ref.read(sharedPreferencesProvider).getDouble(_key) ?? 96;

  void set(double width) {
    final clamped = width.clamp(min, max);
    ref.read(sharedPreferencesProvider).setDouble(_key, clamped);
    state = clamped;
  }
}

/// The gap between two cards of a tier, saved across launches; negative
/// gaps overlap the cards, each above its right neighbour.
final tierlistSpacingProvider = NotifierProvider<TierlistSpacing, double>(TierlistSpacing.new);

class TierlistSpacing extends Notifier<double> {
  static const _key = 'tierlistSpacing';
  static const min = -80.0;
  static const max = 24.0;

  @override
  double build() => ref.read(sharedPreferencesProvider).getDouble(_key) ?? 8;

  void set(double spacing) {
    final clamped = spacing.clamp(min, max);
    ref.read(sharedPreferencesProvider).setDouble(_key, clamped);
    state = clamped;
  }
}

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

  /// The feed's height once the user resized it, and whether it is folded
  /// to its header.
  double? _feedHeight;
  bool _feedCollapsed = false;

  Pool get _pool => widget.pool.pool;

  @override
  void initState() {
    super.initState();
    _quality = widget.quality ?? _pool.defaultTierlistQuality;
    _tag = widget.tag;
  }

  void _save(Pool pool) => savePool(ref, pool);

  /// Switches to [quality] and remembers it as the pool's tierlist quality.
  void _useQuality(String? quality) {
    setState(() => _quality = quality);
    // On the latest saved pool, after the save of a quality just created.
    if (quality != null) {
      ref.read(poolsProvider.notifier).change(
          _pool.id, (p) => p.tierlistQuality == quality ? p : p.copyWith(tierlistQuality: quality));
    }
  }

  /// The tiers of the chosen quality, in its preferred order (best first
  /// when descending).
  List<String> get _tiers => _quality == null ? const [] : _pool.orderedValuesOf(_quality!);

  /// Puts [card] in [tier] right before [before], or last; its other
  /// value of the quality goes.
  void _dropOnTier(String tier, CardData card, {String? before}) {
    final cards = [for (final c in widget.pool.tagCards[tier] ?? const <CardData>[]) c.id];
    final at = before == null ? cards.length : cards.indexOf(before);
    if (cards.indexOf(card.id) case final i when i >= 0 && (i == at || i + 1 == at)) return;
    setState(() => _undo.add(_pool));
    _save(_pool.withCardInTag(tier, card.id, before: before));
  }

  /// Moves [tier] one row up ([by] -1) or down (+1) as shown.
  void _moveTier(String tier, int by) {
    final quality = _quality;
    if (quality == null) return;
    final shown = [..._tiers];
    final i = shown.indexOf(tier);
    final j = i + by;
    if (i < 0 || j < 0 || j >= shown.length) return;
    shown.removeAt(i);
    shown.insert(j, tier);
    setState(() => _undo.add(_pool));
    _save(_pool.withValuesOrder(quality, _pool.isDescending(quality) ? shown.reversed.toList() : shown));
  }

  void _toggleOrder() {
    final quality = _quality;
    if (quality == null) return;
    setState(() => _undo.add(_pool));
    _save(_pool.withQualityDescending(quality, !_pool.isDescending(quality)));
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
    await newQualityValue(context, ref, _pool, quality);
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
    if (chosen.isNotEmpty) return _useQuality(chosen);
    final quality = await newPoolQuality(context, ref, _pool);
    if (quality != null && mounted) _useQuality(quality);
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
    final aspect = gameCardAspect(play.pool.game);
    final quality = _quality;
    final infos = ref.watch(poolCardInfoProvider(_pool.id)).value?.infos ?? const <String, CardInfo>{};
    final cardWidth = ref.watch(tierlistCardWidthProvider);
    final spacing = ref.watch(tierlistSpacingProvider);

    final allItems = [
      for (final e in play.entries)
        (card: e.card, info: play.customizedInfo(e.card.id, infos[e.card.id]), tags: play.tagsOfCard(e.card.id)),
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
                    if (quality != null)
                      ActionChip(
                        key: const Key('tierlistEditQuality'),
                        avatar: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(l10n.editQualityTitle),
                        onPressed: () async {
                          final name = await editPoolQuality(context, ref, _pool, quality);
                          if (mounted) _useQuality(name ?? _pool.qualities.firstOrNull);
                        },
                      ),
                    if (quality != null)
                      ActionChip(
                        key: const Key('tierlistOrder'),
                        avatar: Icon(
                          _pool.isDescending(quality) ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 18,
                        ),
                        label: Text(_pool.isDescending(quality) ? l10n.orderDescending : l10n.orderAscending),
                        tooltip: l10n.qualityOrder,
                        onPressed: _toggleOrder,
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
                    SizedBox(
                      width: 200,
                      child: Row(
                        children: [
                          const Icon(Icons.photo_size_select_small, size: 18),
                          Expanded(
                            child: Slider(
                              key: const Key('tierlistCardSize'),
                              min: TierlistCardWidth.min,
                              max: TierlistCardWidth.max,
                              value: cardWidth,
                              label: l10n.cardSize,
                              onChanged: ref.read(tierlistCardWidthProvider.notifier).set,
                            ),
                          ),
                          const Icon(Icons.photo_size_select_large, size: 18),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: Row(
                        children: [
                          const Icon(Icons.layers, size: 18),
                          Expanded(
                            child: Slider(
                              key: const Key('tierlistSpacing'),
                              min: TierlistSpacing.min,
                              max: TierlistSpacing.max,
                              value: spacing,
                              label: l10n.cardSpacing,
                              onChanged: ref.read(tierlistSpacingProvider.notifier).set,
                            ),
                          ),
                          const Icon(Icons.space_bar, size: 18),
                        ],
                      ),
                    ),
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
                              color: valueColor(_pool, tier),
                              onColor: (c) => setTagColor(ref, _pool, tier, c),
                              cards: valued[tier]!,
                              cardWidth: cardWidth,
                              aspect: aspect,
                              spacing: spacing,
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
                _Feed(
                  cards: feed,
                  hint: l10n.tierlistFeedHint,
                  aspect: aspect,
                  height: _feedHeight ?? cardWidth / aspect + 16,
                  collapsed: _feedCollapsed,
                  onToggle: () => setState(() => _feedCollapsed = !_feedCollapsed),
                  onResize: (delta) => setState(() {
                    _feedCollapsed = false;
                    _feedHeight = ((_feedHeight ?? cardWidth / aspect + 16) - delta).clamp(80.0, 600.0);
                  }),
                  onDrop: _dropOnFeed,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tier: its label and rank arrows, then its cards as a gallery
/// wrapping over as many lines as needed, ranked left to right, top to
/// bottom. A drop target for cards of the feed or of other tiers;
/// dropping on a card ranks before it, on free space last.
class _Tier extends StatelessWidget {
  const _Tier({
    super.key,
    required this.label,
    this.color,
    this.onColor,
    required this.cards,
    required this.cardWidth,
    this.aspect = 63 / 88,
    required this.spacing,
    required this.onDrop,
    this.onMoveUp,
    this.onMoveDown,
  });

  final String label;

  /// The value's color, behind the tier; tapping the label changes it.
  final Color? color;
  final ValueChanged<Color?>? onColor;
  final List<CardData> cards;
  final double cardWidth;

  /// Width over height of the cards.
  final double aspect;

  /// The gap between cards; negative to overlap them.
  final double spacing;
  final void Function(CardData card, {String? before}) onDrop;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<CardData>(
      onWillAcceptWithDetails: (d) => cards.lastOrNull?.id != d.data.id,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) => LayoutBuilder(builder: (context, constraints) {
        final hovered = candidates.isNotEmpty;
        final tint = color ?? theme.colorScheme.primary;
        // The label band, the border and the padding around the cards.
        final flowWidth = (constraints.maxWidth - 96 - 2 * 2 - 2 * 8).clamp(cardWidth, double.infinity);
        return AnimatedContainer(
          key: ValueKey('tierRow-$label'),
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: hovered
                ? tint.withValues(alpha: 0.75)
                : color?.withValues(alpha: 0.5) ?? theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered ? Colors.white : tint,
              width: hovered ? 3 : 2,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 96,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        key: ValueKey('tierColor-$label'),
                        onTap: onColor == null ? null : () => _pickColor(context),
                        child: OutlinedText(label, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
                      ),
                      OutlinedText('${cards.length}', style: theme.textTheme.labelMedium),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('tierUp-$label'),
                            icon: const Icon(Icons.arrow_upward, size: 16, shadows: _iconShadows),
                            color: Colors.white,
                            disabledColor: Colors.white38,
                            visualDensity: VisualDensity.compact,
                            onPressed: onMoveUp,
                          ),
                          IconButton(
                            key: ValueKey('tierDown-$label'),
                            icon: const Icon(Icons.arrow_downward, size: 16, shadows: _iconShadows),
                            color: Colors.white,
                            disabledColor: Colors.white38,
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: cardWidth / aspect + 16),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _CardFlow(
                      width: flowWidth,
                      cardWidth: cardWidth,
                      cardHeight: cardWidth / aspect,
                      spacing: spacing,
                      children: [
                        for (final card in cards)
                          _RankedCard(
                            key: ValueKey('ranked-${card.id}'),
                            card: card,
                            width: cardWidth,
                            color: color,
                            onDropBefore: (dropped) => onDrop(dropped, before: card.id),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      }),
    );
  }
}

extension on _Tier {
  /// A sheet of swatches recoloring the value.
  Future<void> _pickColor(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<Color?>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.valueColor} · $label', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ColorPicker(value: color, onChanged: (c) => Navigator.pop(context, c)),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) onColor?.call(chosen);
  }
}

/// Shadows that outline a white icon on any color.
const _iconShadows = [Shadow(color: Colors.black, blurRadius: 3), Shadow(color: Colors.black, blurRadius: 1)];

/// White text with a black outline, readable on any color (tier headers).
class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// A black shadow in every direction: an outline, from a single text.
  static const outline = [
    Shadow(color: Colors.black, offset: Offset(-1.2, -1.2), blurRadius: 0.6),
    Shadow(color: Colors.black, offset: Offset(0, -1.2), blurRadius: 0.6),
    Shadow(color: Colors.black, offset: Offset(1.2, -1.2), blurRadius: 0.6),
    Shadow(color: Colors.black, offset: Offset(-1.2, 0), blurRadius: 0.6),
    Shadow(color: Colors.black, offset: Offset(1.2, 0), blurRadius: 0.6),
    Shadow(color: Colors.black, offset: Offset(-1.2, 1.2), blurRadius: 0.6),
    Shadow(color: Colors.black, offset: Offset(0, 1.2), blurRadius: 0.6),
    Shadow(color: Colors.black, offset: Offset(1.2, 1.2), blurRadius: 0.6),
  ];

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: textAlign,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white, shadows: outline),
      );
}

/// Cards laid out in rows, [spacing] apart; a negative spacing overlaps
/// them so each card sits above its right neighbour and every row covers
/// the one above it, keeping every card's top-left corner clear.
class _CardFlow extends StatelessWidget {
  const _CardFlow({
    required this.width,
    required this.cardWidth,
    required this.cardHeight,
    required this.spacing,
    required this.children,
  });

  /// The width to flow in (measured by the tier, as an intrinsic-height
  /// row cannot hold a layout builder).
  final double width;
  final double cardWidth;
  final double cardHeight;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
        final stepX = cardWidth + spacing;
        final stepY = cardHeight + spacing;
        final columns = (((width - cardWidth) / stepX).floor() + 1).clamp(1, 1 << 16);
        final rows = children.isEmpty ? 0 : (children.length / columns).ceil();
        final height = rows == 0 ? 0.0 : cardHeight + (rows - 1) * stepY;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Painted in this order: within a row from right to left, so
              // the left card is on top; rows top to bottom, so the lower
              // row is on top.
              for (var row = 0; row < rows; row++)
                for (var column = columns - 1; column >= 0; column--)
                  if (row * columns + column < children.length)
                    Positioned(
                      left: column * stepX,
                      top: row * stepY,
                      width: cardWidth,
                      height: cardHeight,
                      child: children[row * columns + column],
                    ),
            ],
          ),
        );
  }
}

/// A card of a tier, sitting on its value's [color] with no rarity
/// marker: dragged to rank it elsewhere, and a drop target that ranks the
/// dropped card right before it.
class _RankedCard extends StatelessWidget {
  const _RankedCard({super.key, required this.card, required this.width, required this.color, required this.onDropBefore});

  final CardData card;
  final double width;
  final Color? color;
  final void Function(CardData card) onDropBefore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<CardData>(
      onWillAcceptWithDetails: (d) => d.data.id != card.id,
      onAcceptWithDetails: (d) => onDropBefore(d.data),
      builder: (context, candidates, _) => Container(
        width: width,
        decoration: candidates.isEmpty
            ? null
            : BoxDecoration(border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3))),
        child: DraggableCard(
          card: card,
          enabled: true,
          child: CardTile(card: card, hideRarity: true),
        ),
      ),
    );
  }
}

/// The cards of the group without a value yet, scrolled sideways, as tall
/// as the zone the user resized by its top edge, or folded to its header;
/// a drop target that takes a card's value away.
/// The feed's cards in a row, with a scrollbar always shown and the mouse
/// wheel scrolling it sideways (a wheel only moves a vertical list).
class _FeedStrip extends StatefulWidget {
  const _FeedStrip({required this.cards, required this.cardWidth});

  final List<CardData> cards;
  final double cardWidth;

  @override
  State<_FeedStrip> createState() => _FeedStripState();
}

class _FeedStripState extends State<_FeedStrip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final delta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
    if (delta == 0) return;
    final position = _controller.position;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) => Listener(
        key: const Key('feedStrip'),
        onPointerSignal: _wheel,
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
            itemCount: widget.cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => SizedBox(
              width: widget.cardWidth,
              child: DraggableCard(card: widget.cards[i], enabled: true, child: CardTile(card: widget.cards[i])),
            ),
          ),
        ),
      );
}

class _Feed extends StatelessWidget {
  const _Feed({
    required this.cards,
    required this.hint,
    required this.height,
    required this.collapsed,
    required this.onToggle,
    required this.onResize,
    required this.onDrop,
    this.aspect = 63 / 88,
  });

  final List<CardData> cards;
  final String hint;
  final double height;
  final bool collapsed;
  final VoidCallback onToggle;

  /// Called with the vertical drag of the top edge (negative: taller).
  final ValueChanged<double> onResize;
  final void Function(CardData card) onDrop;

  /// Width over height of the cards.
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cardWidth = (height - 16) * aspect;
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
                // The resizer: drag the top edge to change the zone's height.
                MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: GestureDetector(
                    key: const Key('feedResizer'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (d) => onResize(d.delta.dy),
                    child: SizedBox(
                      height: 12,
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text('$hint · ${cards.length}', style: theme.textTheme.labelMedium),
                      ),
                    ),
                    IconButton(
                      key: const Key('feedToggle'),
                      tooltip: collapsed ? l10n.expand : l10n.collapse,
                      icon: Icon(collapsed ? Icons.expand_less : Icons.expand_more),
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggle,
                    ),
                  ],
                ),
                if (!collapsed)
                SizedBox(
                  height: height,
                  child: _FeedStrip(cards: cards, cardWidth: cardWidth),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
