import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../catalog/domain/models.dart';
import '../../packs/domain/pack_source.dart';
import '../../pools/domain/pool.dart';
import '../../pools/presentation/pool_loader.dart';
import '../domain/draft_session.dart';

class DraftScreen extends StatelessWidget {
  const DraftScreen({super.key, required this.game, required this.poolId, this.formatId});

  final Game game;
  final String poolId;

  /// The format to play; the pool's first draft format without.
  final String? formatId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) {
          final formats = pool.pool.playFormats.where((f) => f.kind == FormatKind.draft);
          final format = formats.where((f) => f.id == formatId).firstOrNull ?? formats.firstOrNull;
          if (format == null) return PoolTooSmall(pool: pool, neededPacks: 2 * game.draftRounds);
          final seats = pool.seatsForFormat(format);
          if (seats < 2) return PoolTooSmall(pool: pool, neededPacks: 2 * format.rounds.length);
          return DraftView(
            newSession: () {
              final sources = <String, PackSource>{};
              return DraftSession.rounds(
                [
                  for (final round in format.rounds)
                    DraftRound(
                      sources[round.booster] ??= pool.boosterPlay(round.booster)!.newSource(),
                      picks: round.picks,
                      burn: round.burn,
                    ),
                ],
                seats: seats,
              );
            },
          );
        },
      );
}

/// Runs a draft from [newSession]; restarting creates a new one.
class DraftView extends StatefulWidget {
  const DraftView({super.key, required this.newSession});

  final DraftSession Function() newSession;

  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> {
  late DraftSession _session = widget.newSession();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;

    if (session.isFinished) {
      final pool = [...session.userPool]
        ..sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
      return Scaffold(
        appBar: AppBar(
          title: Text('${l10n.draftDone} · ${l10n.cardsCount(pool.length)}'),
          actions: [
            IconButton(
              tooltip: l10n.restart,
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _session = widget.newSession()),
            ),
          ],
        ),
        body: CardGrid(
          itemCount: pool.length,
          itemBuilder: (context, i) => CardTile(card: pool[i]),
        ),
      );
    }

    final pack = session.currentPack;
    final phase = session.phase == DraftPhase.pick
        ? l10n.pickPhase(session.remainingInPhase)
        : l10n.burnPhase(session.remainingInPhase);
    final plain = session.currentRound.picks == 1 && session.currentRound.burn == 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.draftHeader(session.round, session.rounds, session.pick)),
        bottom: plain
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(phase, style: Theme.of(context).textTheme.labelLarge),
                ),
              ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${l10n.yourPool}: ${session.userPool.length}'),
            ),
          ),
        ],
      ),
      body: CardGrid(
        itemCount: pack.length,
        itemBuilder: (context, i) => CardTile(
          card: pack[i],
          onTap: () => setState(() => session.pickCard(pack[i])),
        ),
      ),
    );
  }
}
