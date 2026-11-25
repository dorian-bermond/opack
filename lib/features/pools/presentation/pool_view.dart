import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../card_info/domain/card_filter.dart';
import '../../card_info/domain/card_info.dart';
import '../../card_info/presentation/labels.dart';
import '../../card_text/data/card_text_repository.dart';
import '../../card_text/presentation/card_details_sheet.dart';
import '../../catalog/domain/models.dart';
import '../domain/pool.dart';
import 'marquee_selection.dart';
import 'pool_loader.dart';
import 'pool_widgets.dart';

/// How the editor lays out a pool's cards: compact rows, a picture grid,
/// overlapping stacks grouped by the sort key, or pictures with full text.
enum PoolView { list, gallery, stacks, spoiler }

/// The chosen [PoolView], saved across launches.
final poolViewProvider = NotifierProvider<PoolViewSetting, PoolView>(PoolViewSetting.new);

class PoolViewSetting extends Notifier<PoolView> {
  static const _key = 'poolView';

  @override
  PoolView build() =>
      PoolView.values.asNameMap()[ref.read(sharedPreferencesProvider).getString(_key)] ?? PoolView.list;

  void select(PoolView view) {
    ref.read(sharedPreferencesProvider).setString(_key, view.name);
    state = view;
  }
}

/// Cards per row of a gallery, saved across launches; one setting per
/// [key] (the pool, the search results). `0` means as many as fit.
final galleryColumnsProvider =
    NotifierProvider.family<GalleryColumnsSetting, int, String>(GalleryColumnsSetting.new);

class GalleryColumnsSetting extends Notifier<int> {
  GalleryColumnsSetting(this.key);

  final String key;
  static const max = 12;

  @override
  int build() => ref.read(sharedPreferencesProvider).getInt('galleryColumns:$key') ?? 0;

  void set(int columns) {
    final clamped = columns.clamp(0, max);
    ref.read(sharedPreferencesProvider).setInt('galleryColumns:$key', clamped);
    state = clamped;
  }
}

/// The width of a gallery card when the cards per row are "auto", saved
/// across launches; one setting per [key].
final galleryCardWidthProvider =
    NotifierProvider.family<GalleryCardWidthSetting, double, String>(GalleryCardWidthSetting.new);

class GalleryCardWidthSetting extends Notifier<double> {
  GalleryCardWidthSetting(this.key);

  final String key;
  static const min = 56.0;
  static const max = 320.0;

  @override
  double build() => ref.read(sharedPreferencesProvider).getDouble('galleryCardWidth:$key') ?? 160;

  void set(double width) {
    final clamped = width.clamp(min, max);
    ref.read(sharedPreferencesProvider).setDouble('galleryCardWidth:$key', clamped);
    state = clamped;
  }
}

/// The gap between two gallery cards, saved across launches; negative
/// gaps overlap the cards, each under its right neighbour and the lower
/// row on top, so the top left corners stay clear.
final gallerySpacingProvider =
    NotifierProvider.family<GallerySpacingSetting, double, String>(GallerySpacingSetting.new);

class GallerySpacingSetting extends Notifier<double> {
  GallerySpacingSetting(this.key);

  final String key;
  static const min = -80.0;
  static const max = 24.0;

  @override
  double build() => ref.read(sharedPreferencesProvider).getDouble('gallerySpacing:$key') ?? 8;

  void set(double spacing) {
    final clamped = spacing.clamp(min, max);
    ref.read(sharedPreferencesProvider).setDouble('gallerySpacing:$key', clamped);
    state = clamped;
  }
}

/// The card size and spacing sliders of the gallery under [settingKey],
/// as the tierlist has them.
class GallerySizeControls extends ConsumerWidget {
  const GallerySizeControls({super.key, required this.settingKey});

  final String settingKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final columns = ref.watch(galleryColumnsProvider(settingKey));
    final cardWidth = ref.watch(galleryCardWidthProvider(settingKey));
    final spacing = ref.watch(gallerySpacingProvider(settingKey));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 170,
          child: Row(
            children: [
              const Icon(Icons.photo_size_select_small, size: 18),
              Expanded(
                child: Slider(
                  key: ValueKey('gallerySize-$settingKey'),
                  min: GalleryCardWidthSetting.min,
                  max: GalleryCardWidthSetting.max,
                  value: cardWidth,
                  label: l10n.cardSize,
                  // A fixed number per row sets the size itself.
                  onChanged: columns == 0 ? ref.read(galleryCardWidthProvider(settingKey).notifier).set : null,
                ),
              ),
              const Icon(Icons.photo_size_select_large, size: 18),
            ],
          ),
        ),
        SizedBox(
          width: 170,
          child: Row(
            children: [
              const Icon(Icons.layers, size: 18),
              Expanded(
                child: Slider(
                  key: ValueKey('gallerySpacing-$settingKey'),
                  min: GallerySpacingSetting.min,
                  max: GallerySpacingSetting.max,
                  value: spacing,
                  label: l10n.cardSpacing,
                  onChanged: ref.read(gallerySpacingProvider(settingKey).notifier).set,
                ),
              ),
              const Icon(Icons.space_bar, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

/// A grid of cards [columns] wide (or as many [cardWidth]-wide cards as
/// fit with `0`), [spacing] apart; a negative spacing overlaps them, the
/// stride never below a fifth of a card.
class _GalleryGridDelegate extends SliverGridDelegate {
  const _GalleryGridDelegate({
    required this.columns,
    required this.cardWidth,
    required this.spacing,
    required this.aspect,
  });

  final int columns;
  final double cardWidth;
  final double spacing;
  final double aspect;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final count = columns > 0
        ? columns
        : (((width - cardWidth) / (cardWidth + spacing.clamp(-cardWidth * 0.8, spacing.abs()))).floor() + 1).clamp(1, 1 << 16);
    // The cards of a row share the width with their gaps between them.
    final gap = spacing.clamp(-cardWidth * 0.8, spacing.abs());
    final extent = ((width - gap * (count - 1)) / count).clamp(1.0, double.infinity);
    final height = extent / aspect;
    return SliverGridRegularTileLayout(
      crossAxisCount: count,
      mainAxisStride: (height + gap).clamp(height * 0.2, double.infinity),
      crossAxisStride: extent + gap,
      childMainAxisExtent: height,
      childCrossAxisExtent: extent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_GalleryGridDelegate old) =>
      old.columns != columns || old.cardWidth != cardWidth || old.spacing != spacing || old.aspect != aspect;
}

/// A stepper for the cards per row of the gallery under [settingKey]:
/// "auto", then 1 to 12.
class GalleryColumnsControl extends ConsumerWidget {
  const GalleryColumnsControl({super.key, required this.settingKey});

  final String settingKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final columns = ref.watch(galleryColumnsProvider(settingKey));
    final setting = ref.read(galleryColumnsProvider(settingKey).notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.cardsPerRow, style: Theme.of(context).textTheme.labelMedium),
        IconButton(
          key: ValueKey('fewerColumns-$settingKey'),
          tooltip: l10n.fewerPerRow,
          icon: const Icon(Icons.remove, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: columns > 0 ? () => setting.set(columns - 1) : null,
        ),
        Text(columns == 0 ? l10n.columnsAuto : '$columns'),
        IconButton(
          key: ValueKey('moreColumns-$settingKey'),
          tooltip: l10n.morePerRow,
          icon: const Icon(Icons.add, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: columns < GalleryColumnsSetting.max ? () => setting.set(columns + 1) : null,
        ),
      ],
    );
  }
}

/// The column a card falls in when stacked by [sort]: its mana value, color,
/// level, first letter… `?` when the card has no such value.
String stackLabel(CardSort sort, CardWithInfo item, String language, {String Function(CardData card)? nameOf}) {
  final info = item.info;
  final mtg = info is MtgCardInfo ? info : null;
  final ygo = info is YgoCardInfo ? info : null;
  final opc = info is OpcCardInfo ? info : null;
  String bucket(int? value) => switch (value) {
        null => '?',
        < 1000 => '0-999',
        < 2000 => '1000-1999',
        < 2500 => '2000-2499',
        < 3000 => '2500-2999',
        _ => '3000+',
      };
  return switch (sort) {
    CardSort.name => nameSortKey(nameOf?.call(item.card) ?? item.card.nameFor(language)).characters.firstOrNull?.toUpperCase() ?? '?',
    CardSort.rarity => item.card.rarity.name,
    CardSort.manaValue => switch (mtg?.manaValue) {
        null => '?',
        >= 7 => '7+',
        final mv => '${mv.toInt()}',
      },
    CardSort.color => switch (mtg?.colors ?? opc?.colors) {
        null => '?',
        [] => 'C',
        [final one] => one,
        _ => 'multi',
      },
    CardSort.type => mtg?.types.firstOrNull ?? opc?.type ?? (ygo == null ? '?' : YgoKinds.keyOf(ygo)),
    CardSort.power => mtg?.power ?? (opc?.power == null ? '?' : '${opc!.power}'),
    CardSort.toughness => mtg?.toughness ?? '?',
    CardSort.collector => item.card.id.split('-').first,
    CardSort.level => ygo?.linkRating != null
        ? 'LINK-${ygo!.linkRating}'
        : ygo?.level == null
            ? '?'
            : '${ygo!.level}',
    CardSort.atk => bucket(ygo?.atk),
    CardSort.def => bucket(ygo?.def),
    CardSort.attribute => ygo?.attribute ?? opc?.attribute ?? '?',
    CardSort.race => ygo?.race ?? '?',
    CardSort.archetype => ygo?.archetype ?? '',
    CardSort.cost => opc?.cost == null ? '?' : '${opc!.cost}',
    CardSort.counter => opc?.counter == null ? '?' : '${opc!.counter}',
  };
}

/// How the editor groups the card list under headers: by a sort key, or by
/// tag (a card shows under each of its tags).
enum GroupBy {
  none,

  /// By plain tag (yes/no traits), quality values left aside.
  tag,

  /// By quality value, across every quality or one of them.
  quality,
  rarity,
  manaValue,
  color,
  type,
  collector,
  level,
  atk,
  def,
  attribute,
  race,
  archetype,
  cost;

  static List<GroupBy> forGame(Game game) => switch (game) {
        Game.mtg => const [none, tag, quality, rarity, manaValue, color, type, collector],
        Game.ygo => const [none, tag, quality, rarity, type, level, atk, def, attribute, race, archetype, collector],
        Game.opc => const [none, tag, quality, rarity, cost, color, type, attribute, collector],
      };

  /// The sort key this grouping follows, `null` for the tag groupings.
  CardSort? get sort => switch (this) {
        none || tag || quality => null,
        rarity => CardSort.rarity,
        manaValue => CardSort.manaValue,
        color => CardSort.color,
        type => CardSort.type,
        collector => CardSort.collector,
        level => CardSort.level,
        atk => CardSort.atk,
        def => CardSort.def,
        attribute => CardSort.attribute,
        race => CardSort.race,
        archetype => CardSort.archetype,
        cost => CardSort.cost,
      };

  /// The groups a card belongs to (raw labels; `''` for cards without
  /// tag). The quality groupings take every quality, or only [quality].
  List<String> labelsOf(CardWithInfo item, String language, {String? quality}) => switch (this) {
        none => const [''],
        tag => [
            for (final t in item.tags)
              if (Pool.qualityOf(t) == null) t,
          ].let((tags) => tags.isEmpty ? const [''] : tags),
        GroupBy.quality => [
            for (final t in item.tags)
              if (Pool.qualityOf(t) case final q? when quality == null || q == quality) t,
          ].let((tags) => tags.isEmpty ? const [noValue] : tags),
        // A monster sits under each of its types (Dragon, Tuner…).
        race => switch (item.info) {
            YgoCardInfo(kind: YgoKind.monster, :final types) when types.isNotEmpty => types,
            _ => const ['?'],
          },
        _ => [stackLabel(sort!, item, language)],
      };

  /// Whether this grouping asks which quality, in a pool with several.
  bool get asksQuality => this == quality;

  /// The group of cards holding no value of the quality.
  static const noValue = 'ø';

  /// Whether this groups by tags (so headers are tag labels).
  bool get byTags => this == tag || this == quality;
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

String groupLabel(AppLocalizations l10n, GroupBy group, {Game? game}) => switch (group) {
      GroupBy.none => l10n.groupNone,
      GroupBy.tag => l10n.facetTag,
      GroupBy.quality => l10n.tierlistQuality,
      _ => sortLabel(l10n, group.sort!, game: game),
    };

/// A raw group label as the user reads it: a number alone says little, so
/// a numeric grouping names itself (`Level / Rank 8`, `ATK 2500-2999`).
String groupHeader(AppLocalizations l10n, GroupBy group, String label, {Game? game}) => switch (group) {
      GroupBy.tag => label.isEmpty ? l10n.noTagGroup : tagLabel(l10n, label),
      GroupBy.quality => label == GroupBy.noValue ? GroupBy.noValue : tagLabel(l10n, label),
      GroupBy.manaValue ||
      GroupBy.level ||
      GroupBy.atk ||
      GroupBy.def ||
      GroupBy.cost ||
      GroupBy.collector =>
        '${groupLabel(l10n, group, game: game)} ${valueLabel(l10n, label)}',
      _ => valueLabel(l10n, label),
    };

/// What the views need to show and change copies.
class PoolCardActions {
  const PoolCardActions({
    required this.copiesOf,
    required this.listedOf,
    required this.changed,
    required this.setCopies,
    required this.tint,
    required this.onTags,
    required this.tagsOf,
    this.onTap,
    this.trailing,
    this.draggable = false,
    this.selected,
    this.onSelect,
    this.onMenu,
  });

  final int? Function(CardData card) copiesOf;
  final int Function(CardData card) listedOf;
  final bool Function(CardData card) changed;
  final void Function(CardData card, int? copies) setCopies;

  /// A color layer over the card while tags are assigned in bulk.
  final Color? Function(CardData card) tint;

  /// Opens the card's tag picker.
  final void Function(CardData card) onTags;

  /// The card's tags as the user reads them.
  final List<String> Function(CardData card) tagsOf;

  /// Replaces the copies sheet on tap (bulk tagging).
  final void Function(CardData card)? onTap;

  /// Replaces the copies and tags controls of each card (cards shown
  /// outside the pool, such as search results); the copies badge goes too.
  final Widget Function(CardData card)? trailing;

  /// Whether cards can be dragged (onto tag baskets).
  final bool draggable;

  /// The gallery's selection: whether a card is in it, a tap putting it in
  /// or taking it out ([onSelect]), and a right-click or long-press opening
  /// the operations on the selected cards at that position ([onMenu]).
  /// Without them a tap asks for the copies.
  final bool Function(CardData card)? selected;
  final void Function(CardData card)? onSelect;
  final void Function(CardData card, Offset position)? onMenu;

  /// Whether cards are being selected: a selection is wanted and bulk
  /// tagging does not keep the tap for itself.
  bool get selecting => onSelect != null && onTap == null;
}

/// [child] showing [card], dragged as a small picture of it when
/// [enabled]; a press starts the drag at once, so the list does not
/// scroll from a card in that mode.
class DraggableCard extends StatelessWidget {
  const DraggableCard({super.key, required this.card, required this.enabled, required this.child});

  final CardData card;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Draggable<CardData>(
      key: ValueKey('drag-${card.id}'),
      data: card,
      feedback: SizedBox(
        width: 120,
        child: Material(color: Colors.transparent, child: CardTile(card: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}

/// Asks for a copy count with a sheet of options; `null` when dismissed.
Future<({int? copies})?> pickCopies(BuildContext context, int? current) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<({int? copies})>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final n in copiesOptions(current))
            ListTile(
              leading: Icon(n == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(n == null ? l10n.unlimitedCopies : l10n.copiesCount(n)),
              onTap: () => Navigator.pop(context, (copies: n)),
            ),
        ],
      ),
    ),
  );
}

/// When a card picture carries its copies badge (`×1`, `×3`): never, only
/// on the cards set apart from the pool's preset, or always.
enum CopiesBadgeMode { none, changed, always }

/// The chosen [CopiesBadgeMode], saved across launches; the changed cards
/// only by default.
final copiesBadgeProvider = NotifierProvider<CopiesBadgeSetting, CopiesBadgeMode>(CopiesBadgeSetting.new);

class CopiesBadgeSetting extends Notifier<CopiesBadgeMode> {
  static const _key = 'copiesBadge';

  @override
  CopiesBadgeMode build() =>
      CopiesBadgeMode.values.asNameMap()[ref.read(sharedPreferencesProvider).getString(_key)] ??
      CopiesBadgeMode.changed;

  void select(CopiesBadgeMode mode) {
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
    state = mode;
  }
}

/// A small copies badge over a card picture.
class _CopiesBadge extends StatelessWidget {
  const _CopiesBadge({required this.copies, required this.changed});

  final int? copies;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: changed ? theme.colorScheme.primary : theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '×${copiesLabel(copies)}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: changed ? theme.colorScheme.onPrimary : null,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// [row] as a card the editor's selection rectangle catches, with a
/// right-click opening the operations on the selection; plain when cards
/// are not being selected.
Widget _selectable(CardData card, PoolCardActions actions, Widget row) {
  if (!actions.selecting) return row;
  final onMenu = actions.onMenu;
  return MarqueeTarget(
    id: card.id,
    child: onMenu == null
        ? row
        : GestureDetector(
            onSecondaryTapUp: (d) => onMenu(card, d.globalPosition),
            child: row,
          ),
  );
}

/// A card picture with its copies badge; tapping asks for the copies, or,
/// when [selectable] and the actions hold a selection, selects the card.
class _PictureCard extends ConsumerWidget {
  const _PictureCard({required this.card, required this.actions, this.selectable = false});

  final CardData card;
  final PoolCardActions actions;
  final bool selectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = ref.watch(copiesBadgeProvider);
    final tint = actions.tint(card);
    // Bulk tagging keeps the tap for itself.
    final selecting = selectable && actions.onTap == null;
    final onSelect = selecting ? actions.onSelect : null;
    final onMenu = selecting ? actions.onMenu : null;
    final selected = selecting && (actions.selected?.call(card) ?? false);
    final picture = _picture(context, tint: tint, onSelect: onSelect, onMenu: onMenu, selected: selected, badge: badge);
    // A selectable card is caught by the editor's selection rectangle.
    return onSelect == null ? picture : MarqueeTarget(id: card.id, child: picture);
  }

  Widget _picture(
    BuildContext context, {
    required Color? tint,
    required CopiesBadgeMode badge,
    required void Function(CardData card)? onSelect,
    required void Function(CardData card, Offset position)? onMenu,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    return DraggableCard(
      card: card,
      enabled: actions.draggable,
      child: Stack(
      children: [
        CardTile(
          card: card,
          onTap: () async {
            if (actions.onTap case final onTap?) return onTap(card);
            if (onSelect != null) return onSelect(card);
            final picked = await pickCopies(context, actions.copiesOf(card));
            if (picked != null) actions.setCopies(card, picked.copies);
          },
          onMenu: onMenu == null ? null : (position) => onMenu(card, position),
        ),
        if (selected) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: ValueKey('selected-${card.id}'),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary, width: 4),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: IgnorePointer(
              child: CircleAvatar(
                radius: 11,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
        ],
        if (tint != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tint, width: 3),
                ),
              ),
            ),
          ),
        if (actions.trailing == null &&
            (badge == CopiesBadgeMode.always || (badge == CopiesBadgeMode.changed && actions.changed(card))))
          Positioned(
            right: 8,
            bottom: 8,
            child: IgnorePointer(
              child: _CopiesBadge(copies: actions.copiesOf(card), changed: actions.changed(card)),
            ),
          ),
      ],
      ),
    );
  }
}

/// Pictures in a grid, [columns] per row (as many 160 px ones as fit
/// when 0). With a selection in [actions], a tap selects a card and a
/// right-click or long-press opens the operations on the selected ones.
class PoolGallerySliver extends StatelessWidget {
  const PoolGallerySliver({
    super.key,
    required this.items,
    required this.actions,
    this.columns = 0,
    this.cardWidth = 160,
    this.spacing = 8,
  });

  final List<CardWithInfo> items;
  final PoolCardActions actions;

  /// Cards per row; `0` for as many [cardWidth]-wide cards as fit.
  final int columns;
  final double cardWidth;

  /// The gap between cards; negative overlaps them.
  final double spacing;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverGrid.builder(
          gridDelegate: _GalleryGridDelegate(
            columns: columns,
            cardWidth: cardWidth,
            spacing: spacing,
            aspect: items.isEmpty ? 63 / 88 : cardAspectRatio(items.first.card),
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _PictureCard(card: items[i].card, actions: actions, selectable: true),
        ),
      );
}

/// Overlapping columns, one per value of the sort key, scrolled sideways.
class PoolStacksSliver extends StatelessWidget {
  const PoolStacksSliver({
    super.key,
    required this.items,
    required this.actions,
    required this.labelOf,
    required this.header,
    this.onHeaderMenu,
  });

  /// A right-click on a column's header, with the column's cards.
  final void Function(List<CardWithInfo> cards, Offset position)? onHeaderMenu;

  final List<CardWithInfo> items;
  final PoolCardActions actions;

  /// The column(s) a card goes to.
  final List<String> Function(CardWithInfo item) labelOf;

  /// A column label as the user reads it.
  final String Function(String label) header;

  static const cardWidth = 130.0;
  static const cardHeight = cardWidth * 88 / 63;
  static const step = 28.0;

  /// A column is cut into stacks of at most this many cards, laid side by
  /// side and wrapping, so the width serves rather than the height.
  static const maxPerStack = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = <String, List<CardWithInfo>>{};
    for (final item in items) {
      for (final label in labelOf(item)) {
        (columns[label] ??= []).add(item);
      }
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            // One panel per group, its header once, its stacks side by
            // side inside and wrapping when the group is large.
            for (final MapEntry(key: label, value: cards) in columns.entries)
              Card(
                key: ValueKey('stackGroup-$label'),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                        child: GestureDetector(
                          key: ValueKey('stackHeader-$label'),
                          onSecondaryTapUp: onHeaderMenu == null ? null : (d) => onHeaderMenu!(cards, d.globalPosition),
                          child: Text('${header(label)} · ${cards.length}', style: theme.textTheme.titleSmall),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var start = 0; start < cards.length; start += maxPerStack)
                            SizedBox(
                              key: ValueKey('stack-$label-$start'),
                              width: cardWidth,
                              height: cardHeight + step * ((cards.length - start).clamp(1, maxPerStack) - 1),
                              child: Stack(
                                children: [
                                  for (final (i, item) in cards.skip(start).take(maxPerStack).indexed)
                                    Positioned(
                                      top: i * step,
                                      width: cardWidth,
                                      height: cardHeight,
                                      child: _PictureCard(card: item.card, actions: actions, selectable: true),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Each card with its picture, name, details and full text.
class PoolSpoilerSliver extends ConsumerWidget {
  const PoolSpoilerSliver({
    super.key,
    required this.items,
    required this.actions,
    required this.language,
  });

  final List<CardWithInfo> items;
  final PoolCardActions actions;
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (:card, :info, tags: _) = items[i];
        final listedTimes = actions.listedOf(card);
        final texts = switch (info) {
          MtgCardInfo(:final faces) => [
              for (final face in faces) ...[
                if (faces.length > 1) face.name,
                ?face.text,
                if (face.flavor case final flavor?) '— $flavor',
              ],
            ],
          YgoCardInfo(:final text?) => [text],
          _ => const <String>[],
        };
        final tags = actions.tagsOf(card);
        final selecting = actions.selecting;
        final selected = selecting && (actions.selected?.call(card) ?? false);
        return _selectable(
          card,
          actions,
          DraggableCard(
          card: card,
          enabled: actions.draggable,
          child: Material(
          color: selected
              ? theme.colorScheme.primaryContainer
              : actions.tint(card)?.withValues(alpha: 0.18) ?? Colors.transparent,
          child: InkWell(
            onTap: actions.onTap == null ? null : () => actions.onTap!(card),
            child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: CardTile(card: card)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shownName(ref, card, language),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: actions.changed(card) ? FontWeight.bold : null,
                      ),
                    ),
                    Text(
                      [
                        card.id,
                        card.rarity.label(l10n),
                        if (listedTimes > 1) l10n.listedTimes(listedTimes),
                        if (tags.isNotEmpty) tags.join(', '),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (cardInfoLine(info) case final line?)
                      Text(line, style: theme.textTheme.labelMedium),
                    for (final text in texts)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          text,
                          style: text.startsWith('— ')
                              ? theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)
                              : theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              actions.trailing?.call(card) ??
                  Column(
                    children: [
                      CopiesDropdown(
                        value: actions.copiesOf(card),
                        onChanged: (value) => actions.setCopies(card, value),
                      ),
                      IconButton(
                        tooltip: l10n.cardTags,
                        icon: const Icon(Icons.label_outline, size: 20),
                        onPressed: () => actions.onTags(card),
                      ),
                    ],
                  ),
            ],
          ),
            ),
          ),
          ),
          ),
        );
      },
    );
  }
}

/// Compact rows: name, code, rarity, tags and the card's details line.
class PoolListSliver extends ConsumerWidget {
  const PoolListSliver({super.key, required this.items, required this.actions, required this.language});

  final List<CardWithInfo> items;
  final PoolCardActions actions;
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (:card, :info, tags: _) = items[i];
        final listedTimes = actions.listedOf(card);
        final tags = actions.tagsOf(card);
        final selecting = actions.selecting;
        final selected = selecting && (actions.selected?.call(card) ?? false);
        return _selectable(
          card,
          actions,
          DraggableCard(
          card: card,
          enabled: actions.draggable,
          child: ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          tileColor: actions.tint(card)?.withValues(alpha: 0.18),
          onTap: actions.onTap == null ? null : () => actions.onTap!(card),
          onLongPress: () => showCardDetails(context, card, poolId: PoolScope.of(context), play: PoolScope.playOf(context)),
          title: Text(
            shownName(ref, card, language),
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
          trailing: actions.trailing?.call(card) ??
              Row(
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
          ),
          ),
        );
      },
    );
  }
}
