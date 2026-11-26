import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../catalog/domain/models.dart';
import '../../packs/domain/pack_source.dart';
import '../../packs/presentation/opening_mode.dart';
import '../../packs/presentation/pack_stack.dart';
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
          final l10n = AppLocalizations.of(context);
          final formats = pool.pool.playFormats.where((f) => f.kind == FormatKind.sealed);
          final format = formats.where((f) => f.id == formatId).firstOrNull ?? formats.firstOrNull;
          if (format == null || !pool.canPlay(format)) {
            return PoolTooSmall(pool: pool, neededPacks: format?.rounds.length ?? game.sealedPackCount);
          }
          final sources = <String, PackSource>{};
          return SealedView(
            title: l10n.sealedPool,
            subtitle: [pool.name, pool.config.label(AppLocalizations.of(context)), l10n.packsCount(format.rounds.length)].join(' · '),
            deal: () => [
              for (final round in format.rounds)
                (sources[round.booster] ??= pool.boosterPlay(round.booster)!.newSource()).nextPack(),
            ],
          );
        },
      );
}

/// One card of a sealed deal: which pack it came in and its place in it.
typedef SealedCard = ({int pack, int slot, CardData card});

/// The cards of [packs] in [order]: pack after pack (A1, A2… B1, B2…),
/// slot after slot (A1, B1… A2, B2…), or the best first (by rarity, packs
/// and slots breaking ties).
List<SealedCard> sealedOrder(List<List<CardData>> packs, SealedOrder order) {
  final cards = [
    for (final (p, pack) in packs.indexed)
      for (final (s, card) in pack.indexed) (pack: p, slot: s, card: card),
  ];
  switch (order) {
    case SealedOrder.byBooster:
      return cards;
    case SealedOrder.bySlot:
      return cards..sort((a, b) => a.slot != b.slot ? a.slot - b.slot : a.pack - b.pack);
    case SealedOrder.byQuality:
      return cards
        ..sort((a, b) => a.card.rarity != b.card.rarity
            ? b.card.rarity.index - a.card.rarity.index
            : a.pack != b.pack
                ? a.pack - b.pack
                : a.slot - b.slot);
  }
}

/// Opens the packs [deal] gives (a fresh deal of a pool, or the packs a
/// host sent) the way a loose pack is opened (a grid of face-down cards,
/// or a stack swiped card by card), in the order the user picks.
class SealedView extends ConsumerStatefulWidget {
  const SealedView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.deal,
    this.canRedeal = true,
  });

  final String title;
  final String subtitle;
  final List<List<CardData>> Function() deal;

  /// Whether "deal again" makes sense: not with packs dealt elsewhere.
  final bool canRedeal;

  @override
  ConsumerState<SealedView> createState() => _SealedViewState();
}

class _SealedViewState extends ConsumerState<SealedView> {
  late List<List<CardData>> _packs = widget.deal();

  /// Cards turned face up, as (pack, slot), so a change of order keeps them.
  final Set<(int, int)> _revealed = {};
  int _deals = 0;

  void _dealAgain() => setState(() {
        _packs = widget.deal();
        _revealed.clear();
        _deals++;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = ref.watch(sealedOrderProvider);
    final swipe = ref.watch(openingModeProvider) == OpeningMode.swipe;
    final cards = sealedOrder(_packs, order);
    final total = cards.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${widget.subtitle} · ${l10n.cardsCount(total)}'),
          ),
        ),
        actions: [
          PopupMenuButton<SealedOrder>(
            key: const Key('sealedOrder'),
            tooltip: l10n.sealedOrder,
            icon: const Icon(Icons.sort),
            initialValue: order,
            onSelected: ref.read(sealedOrderProvider.notifier).select,
            itemBuilder: (context) => [
              for (final o in SealedOrder.values)
                PopupMenuItem(value: o, child: Text(o.label(l10n))),
            ],
          ),
          if (widget.canRedeal)
            IconButton(
              tooltip: l10n.dealAgain,
              icon: const Icon(Icons.refresh),
              onPressed: _dealAgain,
            ),
        ],
      ),
      body: swipe
          ? PackStack(key: ValueKey((_deals, order)), cards: [for (final c in cards) c.card])
          : CardGrid(
              key: ValueKey((_deals, order)),
              itemCount: total,
              itemBuilder: (context, i) {
                final (:pack, :slot, :card) = cards[i];
                return CardTile(
                  card: card,
                  revealed: _revealed.contains((pack, slot)),
                  onTap: () => setState(() => _revealed.add((pack, slot))),
                );
              },
            ),
      bottomNavigationBar: swipe
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(
                  onPressed: _revealed.length == total
                      ? null
                      : () => setState(() => _revealed.addAll([for (final c in cards) (c.pack, c.slot)])),
                  child: Text(l10n.revealAll),
                ),
              ),
            ),
    );
  }
}
