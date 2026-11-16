import 'package:flutter/material.dart';
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
String stackLabel(CardSort sort, CardWithInfo item, String language) {
  final info = item.info;
  final mtg = info is MtgCardInfo ? info : null;
  final ygo = info is YgoCardInfo ? info : null;
  String bucket(int? value) => switch (value) {
        null => '?',
        < 1000 => '0-999',
        < 2000 => '1000-1999',
        < 2500 => '2000-2499',
        < 3000 => '2500-2999',
        _ => '3000+',
      };
  return switch (sort) {
    CardSort.name => item.card.nameFor(language).characters.first.toUpperCase(),
    CardSort.rarity => item.card.rarity.name,
    CardSort.manaValue => switch (mtg?.manaValue) {
        null => '?',
        >= 7 => '7+',
        final mv => '${mv.toInt()}',
      },
    CardSort.color => switch (mtg?.colors) {
        null => '?',
        [] => 'C',
        [final one] => one,
        _ => 'multi',
      },
    CardSort.type => mtg?.types.firstOrNull ?? '?',
    CardSort.power => mtg?.power ?? '?',
    CardSort.toughness => mtg?.toughness ?? '?',
    CardSort.collector => item.card.id.split('-').first,
    CardSort.level => ygo?.linkRating != null
        ? 'LINK-${ygo!.linkRating}'
        : ygo?.level == null
            ? '?'
            : '${ygo!.level}',
    CardSort.atk => bucket(ygo?.atk),
    CardSort.def => bucket(ygo?.def),
    CardSort.attribute => ygo?.attribute ?? '?',
    CardSort.race => ygo?.race ?? '?',
    CardSort.archetype => ygo?.archetype ?? '',
  };
}

/// How the editor groups the card list under headers: by a sort key, or by
/// tag (a card shows under each of its tags).
enum GroupBy {
  none,

  /// By plain tag (yes/no traits), quality values left aside.
  tag,

  /// By quality value, across every quality.
  quality,

  /// By plain tag and by quality value alike.
  tagAndQuality,
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
  archetype;

  static List<GroupBy> forGame(Game game) => switch (game) {
        Game.mtg => const [none, tag, quality, tagAndQuality, rarity, manaValue, color, type, collector],
        Game.ygo => const [none, tag, quality, tagAndQuality, rarity, level, atk, def, attribute, race, archetype, collector],
      };

  /// The sort key this grouping follows, `null` for the tag groupings.
  CardSort? get sort => switch (this) {
        none || tag || quality || tagAndQuality => null,
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
      };

  /// The groups a card belongs to (raw labels; `''` for cards without tag).
  List<String> labelsOf(CardWithInfo item, String language) => switch (this) {
        none => const [''],
        tag => [
            for (final t in item.tags)
              if (Pool.qualityOf(t) == null) t,
          ].let((tags) => tags.isEmpty ? const [''] : tags),
        quality => [
            for (final t in item.tags)
              if (Pool.qualityOf(t) != null) t,
          ].let((tags) => tags.isEmpty ? const [''] : tags),
        tagAndQuality => item.tags.toList().let((tags) => tags.isEmpty ? const [''] : tags),
        _ => [stackLabel(sort!, item, language)],
      };

  /// Whether this groups by tags (so headers are tag labels).
  bool get byTags => this == tag || this == quality || this == tagAndQuality;
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

String groupLabel(AppLocalizations l10n, GroupBy group) => switch (group) {
      GroupBy.none => l10n.groupNone,
      GroupBy.tag => l10n.facetTag,
      GroupBy.quality => l10n.tierlistQuality,
      GroupBy.tagAndQuality => '${l10n.facetTag} + ${l10n.tierlistQuality}',
      _ => sortLabel(l10n, group.sort!),
    };

/// A raw group label as the user reads it.
String groupHeader(AppLocalizations l10n, GroupBy group, String label) => switch (group) {
      GroupBy.tag => label.isEmpty ? l10n.noTagGroup : tagLabel(l10n, label),
      GroupBy.quality => label.isEmpty ? l10n.noQualityGroup : tagLabel(l10n, label),
      GroupBy.tagAndQuality => label.isEmpty ? l10n.noTagGroup : tagLabel(l10n, label),
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

/// A card picture with its copies badge; tapping asks for the copies.
class _PictureCard extends StatelessWidget {
  const _PictureCard({required this.card, required this.actions});

  final CardData card;
  final PoolCardActions actions;

  @override
  Widget build(BuildContext context) {
    final tint = actions.tint(card);
    return DraggableCard(
      card: card,
      enabled: actions.draggable,
      child: Stack(
      children: [
        CardTile(
          card: card,
          onTap: () async {
            if (actions.onTap case final onTap?) return onTap(card);
            final picked = await pickCopies(context, actions.copiesOf(card));
            if (picked != null) actions.setCopies(card, picked.copies);
          },
        ),
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
        if (actions.trailing == null)
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
/// when 0).
class PoolGallerySliver extends StatelessWidget {
  const PoolGallerySliver({super.key, required this.items, required this.actions, this.columns = 0});

  final List<CardWithInfo> items;
  final PoolCardActions actions;
  final int columns;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverGrid.builder(
          gridDelegate: columns > 0
              ? SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 63 / 88,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                )
              : const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  childAspectRatio: 63 / 88,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
          itemCount: items.length,
          itemBuilder: (context, i) => _PictureCard(card: items[i].card, actions: actions),
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
  });

  final List<CardWithInfo> items;
  final PoolCardActions actions;

  /// The column(s) a card goes to.
  final List<String> Function(CardWithInfo item) labelOf;

  /// A column label as the user reads it.
  final String Function(String label) header;

  static const cardWidth = 130.0;
  static const cardHeight = cardWidth * 88 / 63;
  static const step = 28.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = <String, List<CardWithInfo>>{};
    for (final item in items) {
      for (final label in labelOf(item)) {
        (columns[label] ??= []).add(item);
      }
    }
    final tallest = columns.values.fold(0, (m, c) => c.length > m ? c.length : m);
    // Cards, the label above them and the list's own padding.
    final height = tallest == 0 ? 0.0 : cardHeight + step * (tallest - 1) + 56;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: height,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          children: [
            for (final MapEntry(key: label, value: cards) in columns.entries)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${header(label)} · ${cards.length}',
                        style: theme.textTheme.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: cardHeight + step * (cards.length - 1),
                        child: Stack(
                          children: [
                            for (final (i, item) in cards.indexed)
                              Positioned(
                                top: i * step,
                                width: cardWidth,
                                height: cardHeight,
                                child: _PictureCard(card: item.card, actions: actions),
                              ),
                          ],
                        ),
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
class PoolSpoilerSliver extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
        return DraggableCard(
          card: card,
          enabled: actions.draggable,
          child: Material(
          color: actions.tint(card)?.withValues(alpha: 0.18) ?? Colors.transparent,
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
                      card.nameFor(language),
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
        );
      },
    );
  }
}

/// Compact rows: name, code, rarity, tags and the card's details line.
class PoolListSliver extends StatelessWidget {
  const PoolListSliver({super.key, required this.items, required this.actions, required this.language});

  final List<CardWithInfo> items;
  final PoolCardActions actions;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (:card, :info, tags: _) = items[i];
        final listedTimes = actions.listedOf(card);
        final tags = actions.tagsOf(card);
        return DraggableCard(
          card: card,
          enabled: actions.draggable,
          child: ListTile(
          dense: true,
          tileColor: actions.tint(card)?.withValues(alpha: 0.18),
          onTap: actions.onTap == null ? null : () => actions.onTap!(card),
          onLongPress: () => showCardDetails(context, card, poolId: PoolScope.of(context)),
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
        );
      },
    );
  }
}
