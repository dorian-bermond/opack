import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/booster_cover.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../catalog/domain/models.dart';
import '../../pools/domain/play_pool.dart';
import '../../pools/domain/pool.dart';
import '../../pools/presentation/pool_loader.dart';
import '../domain/pack_source.dart';
import 'opening_mode.dart';
import 'pack_stack.dart';
import 'sealed_pack.dart';

/// Opens loose packs dealt from a pool, one at a time.
class PackOpeningScreen extends StatelessWidget {
  const PackOpeningScreen({super.key, required this.game, required this.poolId});

  final Game game;
  final String poolId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => pool.canDeal(1)
            ? _PackOpening(pool: pool)
            : PoolTooSmall(pool: pool, neededPacks: 1),
      );
}

class _PackOpening extends ConsumerStatefulWidget {
  const _PackOpening({required this.pool});

  final PlayPool pool;

  @override
  ConsumerState<_PackOpening> createState() => _PackOpeningState();
}

class _PackOpeningState extends ConsumerState<_PackOpening> {
  /// The kind of booster being opened, by name (the default one at start).
  late String _kind = widget.pool.pool.boosters.firstOrNull?.name ?? BoosterDef.defaultName;
  final _sources = <String, PackSource>{};

  BoosterPlay get _play => widget.pool.boosterPlay(_kind)!;
  PackSource get _source => _sources[_kind] ??= _play.newSource();

  List<CardData>? _pack;
  final _opened = <String, int>{};
  final Set<int> _revealed = {};

  bool get _exhausted => switch (_play.packCount) {
        final packs? => (_opened[_kind] ?? 0) >= packs,
        null => false,
      };

  void _open() => setState(() {
        _pack = _source.nextPack();
        _opened[_kind] = (_opened[_kind] ?? 0) + 1;
        _revealed.clear();
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pool = widget.pool;
    final pack = _pack;
    final swipe = ref.watch(openingModeProvider) == OpeningMode.swipe;
    final booster = switch (pool.pool.layout) {
      BoosterLayout(:final booster) => booster,
      RandomLayout() => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(pool.name)),
      body: pack == null
          ? LayoutBuilder(builder: (context, constraints) {
              // The pack takes the height left by the texts around it.
              final packHeight = (constraints.maxHeight - 190).clamp(200.0, 720.0);
              final packWidth = (packHeight * 180 / 280).clamp(120.0, constraints.maxWidth - 32);
              return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pool.pool.boosters.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButton<String>(
                        value: _kind,
                        onChanged: (kind) => setState(() => _kind = kind!),
                        items: [
                          for (final kind in pool.pool.boosters)
                            DropdownMenuItem(value: kind.name, child: Text(kind.name)),
                        ],
                      ),
                    ),
                  SealedPack(
                    key: ValueKey('sealed-${_opened[_kind] ?? 0}'),
                    width: packWidth,
                    height: packWidth * 280 / 180,
                    enabled: !_exhausted,
                    onOpen: _open,
                    child: BoosterCover(
                      set: pool.layoutSet,
                      label: pool.name,
                      booster: booster,
                      custom: pool.pool.cover,
                      width: packWidth,
                      height: packWidth * 280 / 180,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.tapToOpen),
                  if (_play.packCount case final packs?) ...[
                    const SizedBox(height: 4),
                    Text(l10n.packsLeft(packs - (_opened[_kind] ?? 0)), style: theme.textTheme.labelMedium),
                  ],
                  if (pool.layoutSet?.attribution case final attribution?) ...[
                    const SizedBox(height: 24),
                    Text(attribution, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            );
            })
          : swipe
              ? PackStack(key: ValueKey(pack), cards: pack)
              : CardGrid(
                  itemCount: pack.length,
                  itemBuilder: (context, i) => CardTile(
                    card: pack[i],
                    revealed: _revealed.contains(i),
                    onTap: () => setState(() => _revealed.add(i)),
                  ),
                ),
      bottomNavigationBar: pack == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: swipe || _revealed.length == pack.length
                            ? null
                            : () => setState(() => _revealed
                                .addAll(List.generate(pack.length, (i) => i))),
                        child: Text(l10n.revealAll),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _exhausted ? null : _open,
                        child: Text(l10n.openAnother),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
