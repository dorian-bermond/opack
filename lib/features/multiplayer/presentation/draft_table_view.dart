import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../draft/domain/draft_session.dart';
import '../domain/protocol.dart';

/// One seat of a draft played with others: the pack in hand to pick
/// from, who the pass waits on, and the pool once it is over. The same
/// for the host and for a player, fed by a [SeatView].
class DraftTableView extends StatelessWidget {
  const DraftTableView({super.key, required this.seat, required this.onPick, this.title});

  final ValueListenable<SeatView?> seat;
  final void Function(String cardId) onPick;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder<SeatView?>(
      valueListenable: seat,
      builder: (context, view, _) {
        if (view == null) return const Center(child: CircularProgressIndicator());
        if (view.finished) {
          final pool = [...view.pool]..sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
          return Scaffold(
            appBar: AppBar(title: Text('${l10n.draftDone} · ${l10n.cardsCount(pool.length)}')),
            body: CardGrid(itemCount: pool.length, itemBuilder: (context, i) => CardTile(card: pool[i])),
          );
        }
        final waiting = view.remaining == 0;
        final phase = view.phase == DraftPhase.pick ? l10n.pickPhase(view.remaining) : l10n.burnPhase(view.remaining);
        final status = waiting ? l10n.waitingFor(view.waiting.join(', ')) : phase;
        return Scaffold(
          appBar: AppBar(
            title: Text(title ?? l10n.draftHeader(view.round, view.rounds, view.pick)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(status, key: const Key('draftStatus'), style: theme.textTheme.labelLarge),
              ),
            ),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text('${l10n.yourPool}: ${view.pool.length}'),
                ),
              ),
            ],
          ),
          body: Opacity(
            opacity: waiting ? 0.6 : 1,
            child: CardGrid(
              itemCount: view.pack.length,
              itemBuilder: (context, i) => CardTile(
                card: view.pack[i],
                onTap: waiting ? null : () => onPick(view.pack[i].id),
              ),
            ),
          ),
        );
      },
    );
  }
}
