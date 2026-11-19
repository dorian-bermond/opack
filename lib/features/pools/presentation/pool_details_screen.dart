import 'dart:io';

import 'package:flutter/material.dart';
import '../../../shared/widgets/set_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../l10n/app_localizations.dart';
import '../../card_info/presentation/labels.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_actions.dart';
import 'pool_composition_screen.dart';
import 'pool_loader.dart';
import 'pool_widgets.dart';
import 'source_picker.dart';

/// A pool's details: where its cards come from, its tags and how many
/// copies of each card it holds. Reached from the pool list and the editor.
class PoolDetailsScreen extends StatelessWidget {
  const PoolDetailsScreen({super.key, required this.poolId});

  final String poolId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => _PoolDetails(pool: pool),
      );
}

class _PoolDetails extends ConsumerWidget {
  const _PoolDetails({required this.pool});

  final PlayPool pool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final uiLanguage = Localizations.localeOf(context).languageCode;
    final play = pool;
    final saved = play.pool;
    final config = saved.config;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(onTap: () => renamePool(context, ref, saved), child: Text(saved.name)),
        actions: [
          IconButton(
            tooltip: l10n.renamePool,
            icon: const Icon(Icons.edit),
            onPressed: () => renamePool(context, ref, saved),
          ),
          IconButton(
            tooltip: l10n.tierlist,
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => context.push(poolModePath(saved.game, saved.id, 'tierlist')),
          ),
          IconButton(
            tooltip: l10n.editPool,
            icon: const Icon(Icons.edit_note),
            onPressed: () => context.push(poolModePath(saved.game, saved.id, 'edit')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          PoolSection(
            title: l10n.poolSources,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final source in saved.sources)
                  InputChip(
                    avatar: source is SetSource
                        ? SetIcon(saved.game, source.code, size: 18)
                        : const Icon(Icons.view_module, size: 18),
                    label: Text(sourceName(ref, saved.game, source, uiLanguage)),
                    onDeleted: () => savePool(ref, saved.withoutSource(source)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addSource),
                  onPressed: () => addPoolSource(context, ref, play),
                ),
              ],
            ),
          ),
              PoolSection(
            title: l10n.boosterComposition,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    saved.slots.isEmpty
                        ? l10n.noUserSlots
                        : [
                            for (final slot in saved.slots) l10n.slotRow(slot.count, slotLabel(l10n, slot)),
                          ].join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.editComposition),
                  onPressed: () => context.push(poolModePath(saved.game, saved.id, 'composition')),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.sports_esports),
                  label: Text(l10n.formats),
                  onPressed: () => context.push(poolModePath(saved.game, saved.id, 'formats')),
                ),
              ],
            ),
          ),
          PoolSection(
            title: l10n.poolTags,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.tagsHint, style: theme.textTheme.bodySmall),
                Text(l10n.tagChipHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in saved.plainTags)
                      InputChip(
                        avatar: const Icon(Icons.label_outline, size: 18),
                        label: Text('${tagLabel(l10n, name)} · ${play.tagCards[name]?.length ?? 0}'),
                        tooltip: l10n.tagCardsAction,
                        onPressed: () => context.push(
                            '${poolModePath(saved.game, saved.id, 'edit')}?tag=${Uri.encodeQueryComponent(name)}'),
                        onDeleted: () => deletePoolTag(context, ref, play, name),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(l10n.newTag),
                      onPressed: () => newPoolTag(context, ref, saved),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PoolSection(
            title: l10n.qualitiesTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.qualitiesHint, style: theme.textTheme.bodySmall),
                Text(l10n.tagChipHint, style: theme.textTheme.bodySmall),
                for (final quality in saved.qualities) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(qualityLabel(l10n, quality), style: theme.textTheme.titleSmall),
                      IconButton(
                        key: ValueKey('editQuality-$quality'),
                        tooltip: l10n.editQualityTitle,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => editPoolQuality(context, ref, saved, quality),
                      ),
                      IconButton(
                        key: ValueKey('qualityOrder-$quality'),
                        tooltip: '${l10n.qualityOrder}: '
                            '${saved.isDescending(quality) ? l10n.orderDescending : l10n.orderAscending}',
                        icon: Icon(saved.isDescending(quality) ? Icons.arrow_downward : Icons.arrow_upward, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            savePool(ref, saved.withQualityDescending(quality, !saved.isDescending(quality))),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.leaderboard_outlined, size: 18),
                        label: Text(l10n.tierlist),
                        onPressed: () => context.push(
                            '${poolModePath(saved.game, saved.id, 'tierlist')}?quality=${Uri.encodeQueryComponent(quality)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in saved.orderedValuesOf(quality))
                        InputChip(
                          avatar: ColorDot(valueColor(saved, name), size: 14),
                          label: Text('${tagLabel(l10n, name.substring(quality.length + 1))}'
                              ' · ${play.tagCards[name]?.length ?? 0}'
                              '${saved.tags[name]!.copiesSet ? ' · ×${copiesLabel(saved.tags[name]!.copies)}' : ''}'),
                          tooltip: l10n.tagCardsAction,
                          onPressed: () => context.push(
                              '${poolModePath(saved.game, saved.id, 'edit')}?tag=${Uri.encodeQueryComponent(name)}'),
                          onDeleted: () => deletePoolTag(context, ref, play, name),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(l10n.addValue),
                        onPressed: () => newQualityValue(context, ref, saved, quality),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    key: const Key('addQuality'),
                    avatar: const Icon(Icons.category_outlined, size: 18),
                    label: Text(l10n.newQualityTitle),
                    onPressed: () => newPoolQuality(context, ref, saved),
                  ),
                ),
              ],
            ),
          ),
          PoolSection(
            title: l10n.boosterPicture,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.boosterPictureHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (saved.cover case final path? when File(path).existsSync())
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(path), key: const Key('coverThumbnail'), width: 64, height: 96, fit: BoxFit.cover),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('chooseCover'),
                          icon: const Icon(Icons.image_outlined),
                          label: Text(l10n.choosePicture),
                          onPressed: () => pickPoolCover(context, ref, saved),
                        ),
                        if (saved.cover != null)
                          OutlinedButton.icon(
                            key: const Key('clearCover'),
                            icon: const Icon(Icons.restart_alt),
                            label: Text(l10n.removePicture),
                            onPressed: () => clearPoolCover(ref, saved),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          PoolSection(
            title: l10n.poolCopies,
            child: PresetPicker(config: config, onChanged: (c) => savePool(ref, saved.copyWith(config: c))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(play.summary(l10n), style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// A titled block of a pool page.
class PoolSection extends StatelessWidget {
  const PoolSection({super.key, required this.title, required this.child});

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
