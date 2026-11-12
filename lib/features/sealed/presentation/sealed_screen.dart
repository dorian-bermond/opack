import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../catalog/domain/models.dart';
import '../../packs/domain/pack_source.dart';
import '../../pools/domain/play_pool.dart';
import '../../pools/domain/pool.dart';
import '../../pools/presentation/pool_widgets.dart';
import '../../pools/presentation/pool_loader.dart';

class SealedScreen extends StatelessWidget {
  const SealedScreen({super.key, required this.game, required this.poolId, this.formatId});

  final Game game;
  final String poolId;

  /// The format to play; the pool's first sealed format without.
  final String? formatId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) {
          final formats = pool.pool.playFormats.where((f) => f.kind == FormatKind.sealed);
          final format = formats.where((f) => f.id == formatId).firstOrNull ?? formats.firstOrNull;
          if (format == null || !pool.canPlay(format)) {
            return PoolTooSmall(pool: pool, neededPacks: format?.rounds.length ?? game.sealedPackCount);
          }
          return SealedView(pool: pool, format: format);
        },
      );
}

/// Opens the packs of [format] from a fresh deal of [pool] into one sorted
/// pool.
class SealedView extends StatefulWidget {
  const SealedView({super.key, required this.pool, required this.format});

  final PlayPool pool;
  final PlayFormat format;

  int get packCount => format.rounds.length;

  @override
  State<SealedView> createState() => _SealedViewState();
}

class _SealedViewState extends State<SealedView> {
  late List<CardData> _cards = _deal();

  List<CardData> _deal() {
    final sources = <String, PackSource>{};
    return [
      for (final round in widget.format.rounds)
        ...(sources[round.booster] ??= widget.pool.boosterPlay(round.booster)!.newSource()).nextPack(),
    ]..sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pool = widget.pool;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sealedPool),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text([
              pool.name,
              pool.config.label(l10n),
              l10n.packsCount(widget.packCount),
              l10n.cardsCount(_cards.length),
            ].join(' · ')),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.dealAgain,
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _cards = _deal()),
          ),
        ],
      ),
      body: CardGrid(
        itemCount: _cards.length,
        itemBuilder: (context, i) => CardTile(card: _cards[i]),
      ),
    );
  }
}
