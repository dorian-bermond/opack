import 'package:flutter/material.dart';
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
                    avatar: Icon(source is SetSource ? Icons.style : Icons.view_module, size: 18),
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
                            for (final slot in saved.slots) l10n.slotRow(slot.count, slotOptionsLabel(l10n, slot)),
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
                Text(l10n.tagChipHint, style: theme.textTheme.bodySmall),
                Text(l10n.qualityHint, style: theme.textTheme.bodySmall),
                for (final (quality, names) in tagsByQuality(saved)) ...[
                  const SizedBox(height: 8),
                  if (quality != null)
                    Text(qualityLabel(l10n, quality), style: theme.textTheme.labelMedium)
                  else if (saved.qualities.isNotEmpty)
                    Text(l10n.plainTags, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in names)
                        InputChip(
                          avatar: Icon(quality == null ? Icons.label_outline : Icons.radio_button_checked, size: 18),
                          label: Text('${quality == null ? tagLabel(l10n, name) : tagLabel(l10n, name.substring(quality.length + 1))}'
                              ' · ${play.tagCards[name]?.length ?? 0}'),
                          tooltip: l10n.tagCardsAction,
                          onPressed: () => context.push(
                              '${poolModePath(saved.game, saved.id, 'edit')}?tag=${Uri.encodeQueryComponent(name)}'),
                          onDeleted: () => deletePoolTag(context, ref, play, name),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(l10n.newTag),
                        onPressed: () => newPoolTag(context, ref, saved, quality: quality),
                      ),
                    ],
                  ),
                ],
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

/// The pool's tags grouped by quality, plain tags first (under `null`),
/// each quality in the order its tags list them; the plain group is
/// always present so a tag can be added there.
List<(String?, List<String>)> tagsByQuality(Pool pool) {
  final groups = <String?, List<String>>{null: []};
  for (final tag in pool.tags.keys) {
    (groups[Pool.qualityOf(tag)] ??= []).add(tag);
  }
  return [for (final MapEntry(:key, :value) in groups.entries) (key, value)];
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
