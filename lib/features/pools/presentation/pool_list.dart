import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../../catalog/presentation/home_screen.dart';
import '../../cube/data/cube_repository.dart';
import '../data/pool_repository.dart';
import '../domain/pool.dart';
import 'pool_widgets.dart';
import 'source_picker.dart';

/// Saves a new pool started from [source] (with [booster] for a set), or an
/// empty one without, and opens its editor.
Future<void> createPool(
  BuildContext context,
  WidgetRef ref,
  Game game,
  PoolSource? source, {
  BoosterType? booster,
}) async {
  final l10n = AppLocalizations.of(context);
  final language = Localizations.localeOf(context).languageCode;
  final Pool? pool = switch (source) {
    null => Pool.empty(game, name: l10n.newPool),
    SetSource(:final code) => await ref
        .read(catalogRepositoryProvider)
        .loadSet(game, code)
        .then((set) => Pool.ofSet(set, name: set.nameFor(language), booster: booster)),
    CubeSource(:final id) => (await ref.read(cubesProvider.future))
        .where((c) => c.id == id)
        .map(Pool.ofCube)
        .firstOrNull,
    CardsSource() => Pool.empty(game, name: l10n.newPool).withSource(source),
  };
  if (pool == null) return;
  await ref.read(poolsProvider.notifier).save(pool);
  if (context.mounted) context.go(poolModePath(game, pool.id, 'edit'));
}

/// Asks which game, then how to start a pool (empty, from a set, from a
/// cube), and creates it.
Future<void> startPool(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final game = await pickGame(context);
  if (game == null || !context.mounted) return;
  final choice = await showModalBottomSheet<_Start>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (start, icon, label) in [
            (_Start.empty, Icons.playlist_add, l10n.poolEmpty),
            (_Start.set, Icons.style, l10n.poolFromSet),
            (_Start.cube, Icons.view_module, l10n.poolFromCube),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.pop(context, start),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  PoolSource? source;
  if (choice != _Start.empty) {
    source = await pickPoolSource(context,
        game: game, sets: choice == _Start.set, cubes: choice == _Start.cube);
    if (source == null || !context.mounted) return;
  }
  await createPool(context, ref, game, source);
}

enum _Start { empty, set, cube }

/// The saved pools of every game.
class PoolList extends ConsumerWidget {
  const PoolList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newPool),
        onPressed: () => startPool(context, ref),
      ),
      body: ref.watch(poolsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (all) {
              final mine = all;
              if (mine.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.noPools, textAlign: TextAlign.center),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: mine.length,
                itemBuilder: (context, i) => _PoolTile(pool: mine[i], key: ValueKey(mine[i].id)),
              );
            },
          ),
    );
  }
}

class _PoolTile extends ConsumerWidget {
  const _PoolTile({super.key, required this.pool});

  final Pool pool;

  /// Plays the pool's only format of [kind], or asks which one.
  Future<void> _play(BuildContext context, Pool pool, FormatKind kind) async {
    final l10n = AppLocalizations.of(context);
    final formats = pool.playFormats.where((f) => f.kind == kind).toList();
    final mode = kind.name;
    if (formats.isEmpty) return;
    String path(PlayFormat format) => '${poolModePath(pool.game, pool.id, mode)}?format=${format.id}';
    if (formats.length == 1) return context.go(path(formats.single));
    final chosen = await showModalBottomSheet<PlayFormat>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(l10n.chooseFormat, style: Theme.of(context).textTheme.titleMedium)),
            for (final format in formats)
              ListTile(
                leading: Icon(kind == FormatKind.sealed ? Icons.inventory_2 : Icons.groups),
                title: Text(format.name),
                subtitle: Text(format.rounds.map((r) => r.booster).join(', ')),
                onTap: () => Navigator.pop(context, format),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && context.mounted) context.go(path(chosen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final pools = ref.read(poolsProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // The whole card opens the editor; the buttons keep their own action.
        key: ValueKey('poolTile-${pool.id}'),
        onTap: () => context.go(poolModePath(pool.game, pool.id, 'edit')),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(pool.name, style: theme.textTheme.titleMedium)),
                Tooltip(
                  message: pool.game.label(l10n),
                  child: Chip(
                    label: Text(pool.game.shortLabel),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                PopupMenuButton<void>(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: () => pools.save(pool.copyWith(
                        id: Pool.newId(pool.game),
                        name: l10n.copyOf(pool.name),
                      )),
                      child: ListTile(
                        leading: const Icon(Icons.copy),
                        title: Text(l10n.duplicatePool),
                      ),
                    ),
                    PopupMenuItem(
                      onTap: () => pools.remove(pool.id),
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: Text(l10n.deletePool),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Text(pool.sources.isEmpty
                ? l10n.poolNoSources
                : [
                    for (final source in pool.sources) sourceName(ref, pool.game, source, language),
                  ].join(' + ')),
            Text(pool.config.label(l10n), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.redeem),
                  label: Text(l10n.modeOpen),
                  onPressed: pool.sources.isEmpty ? null : () => context.go(poolModePath(pool.game, pool.id, 'open')),
                ),
                for (final (kind, label, icon) in [
                  (FormatKind.sealed, l10n.modeSealed, Icons.inventory_2),
                  (FormatKind.draft, l10n.modeDraft, Icons.groups),
                ])
                  FilledButton.tonalIcon(
                    icon: Icon(icon),
                    label: Text(label),
                    onPressed: pool.sources.isEmpty ? null : () => _play(context, pool, kind),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline),
                  label: Text(l10n.poolDetails),
                  onPressed: () => context.go(poolModePath(pool.game, pool.id, 'details')),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: Text(l10n.editPool),
                  onPressed: () => context.go(poolModePath(pool.game, pool.id, 'edit')),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.sports_esports),
                  label: Text(l10n.formats),
                  onPressed: () => context.go(poolModePath(pool.game, pool.id, 'formats')),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.boosterComposition),
                  onPressed: pool.sources.isEmpty
                      ? null
                      : () => context.go(poolModePath(pool.game, pool.id, 'composition')),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
