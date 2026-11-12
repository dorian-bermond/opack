import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../catalog/domain/models.dart';

/// A pack as a stack of face-up cards: swipe the top one away to uncover the
/// next, like a Pokémon TCG Pocket pack. Once every card has been swiped the
/// whole pack lies in a grid.
class PackStack extends StatefulWidget {
  const PackStack({super.key, required this.cards});

  final List<CardData> cards;

  @override
  State<PackStack> createState() => _PackStackState();
}

class _PackStackState extends State<PackStack> with SingleTickerProviderStateMixin {
  int _top = 0;
  Offset _drag = Offset.zero;
  late final AnimationController _flyOut = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _top++;
          _drag = Offset.zero;
          _flyOut.reset();
        });
      }
    });

  @override
  void dispose() {
    _flyOut.dispose();
    super.dispose();
  }

  void _release(DragEndDetails details, double width) {
    final flung = details.velocity.pixelsPerSecond.distance > 700;
    if (_drag.distance > width * 0.3 || flung) {
      _flyOut.forward();
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cards = widget.cards;
    if (_top >= cards.length) {
      return CardGrid(itemCount: cards.length, itemBuilder: (context, i) => CardTile(card: cards[i]));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth * 0.6).clamp(160.0, 280.0);
      final remaining = cards.length - _top;
      return Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: width,
                height: width * 88 / 63,
                child: AnimatedBuilder(
                  animation: _flyOut,
                  builder: (context, _) {
                    final direction = _drag == Offset.zero ? const Offset(1, 0) : _drag / _drag.distance;
                    final offset = _drag + direction * (_flyOut.value * constraints.maxWidth);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Up to two cards peek from under the top one.
                        for (final depth in [2, 1])
                          if (_top + depth < cards.length)
                            Positioned.fill(
                              top: depth * 10.0,
                              bottom: -depth * 10.0,
                              child: Transform.scale(
                                scale: 1 - depth * 0.04,
                                child: IgnorePointer(child: CardTile(card: cards[_top + depth])),
                              ),
                            ),
                        Positioned.fill(
                          child: Transform.translate(
                            offset: offset,
                            child: Transform.rotate(
                              angle: offset.dx / constraints.maxWidth * 0.3,
                              child: GestureDetector(
                                key: ValueKey('stackTop$_top'),
                                onPanUpdate: (d) => setState(() => _drag += d.delta),
                                onPanEnd: (d) => _release(d, constraints.maxWidth),
                                child: CardTile(card: cards[_top]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Text(l10n.swipeToReveal, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(l10n.cardsLeft(remaining), style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ],
      );
    });
  }
}
