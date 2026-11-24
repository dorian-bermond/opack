import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../cube/data/cube_repository.dart';
import '../../cube/domain/cube.dart';
import '../data/pool_repository.dart';
import '../../catalog/domain/models.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_widgets.dart';

/// The pool a screen belongs to, for actions on a card that edit the pool
/// (choosing its artwork). `null` outside of a pool screen.
class PoolScope extends InheritedWidget {
  const PoolScope({super.key, required this.poolId, required this.pool, required super.child});

  final String poolId;
  final Pool pool;

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PoolScope>()?.poolId;

  /// The color the pool gives [card]'s marker, `null` to leave it to the
  /// rarity (no pool around, or the rarity chosen).
  static Color? markerColorOf(BuildContext context, CardData card) {
    final pool = context.dependOnInheritedWidgetOfExactType<PoolScope>()?.pool;
    return pool?.markerColorOf(card.id, (tag) => valueColor(pool, tag));
  }

  @override
  bool updateShouldNotify(PoolScope oldWidget) => oldWidget.poolId != poolId || oldWidget.pool != pool;
}

/// Finds the saved pool [poolId] and loads its sets and cubes, then builds
/// [builder] with it ready to deal, under a [PoolScope].
class PoolLoader extends ConsumerWidget {
  const PoolLoader({super.key, required this.poolId, required this.builder});

  final String poolId;
  final Widget Function(BuildContext context, PlayPool pool) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cubes = ref.watch(cubesProvider);
    final pools = ref.watch(poolsProvider);
    // While a save reloads the pools, keep showing the last data so screens
    // keep their state instead of flashing a spinner.
    if (!cubes.hasValue || !pools.hasValue) {
      if (cubes.error ?? pools.error case final error?) return _Failed('$error');
      return const _Loading();
    }

    final Pool? pool = pools.value!.where((p) => p.id == poolId).firstOrNull;
    if (pool == null) return const _Failed(null);

    return ref.watch(poolSetsProvider(poolSetsKey(pool))).when(
          loading: () => const _Loading(),
          error: (error, _) => _Failed('$error'),
          data: (sets) => PoolScope(
            poolId: pool.id,
            pool: pool,
            child: Builder(
              builder: (context) => builder(
                context,
                PlayPool.resolve(pool, sets: sets, cubes: {
                  for (final Cube cube in cubes.value!) cube.id: cube,
                }),
              ),
            ),
          ),
        );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Failed extends StatelessWidget {
  const _Failed(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: message == null ? const Icon(Icons.error_outline) : Text(message!),
        ),
      );
}

/// Shown when a pool cannot deal enough packs for the mode.
class PoolTooSmall extends StatelessWidget {
  const PoolTooSmall({super.key, required this.pool, required this.neededPacks});

  final PlayPool pool;

  /// Packs the mode needs: one to open, the sealed pack count, or two draft
  /// seats.
  final int neededPacks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(pool.name)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            pool.entries.isEmpty
                ? l10n.poolEmptyHint
                : l10n.poolTooSmall(pool.packCount ?? 0, pool.packSize, neededPacks),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
