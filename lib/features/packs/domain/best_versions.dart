import '../../catalog/domain/models.dart';
import 'pack_source.dart';

/// The card a print is a version of: its id without the version suffix
/// onepiece.gg appends (`OP05-119_p2` is a print of `OP05-119`).
String baseCardId(String id) => id.replaceFirst(RegExp(r'_[a-z]+\d*$'), '');

/// Every card of [cards] mapped to the most valuable version of the same
/// card among them: the one dealt at the highest rarity, the latest print
/// when equal. A card without another version maps to itself.
Map<String, CardData> bestVersions(Iterable<CardData> cards) {
  final best = <String, CardData>{};
  for (final card in cards) {
    best.update(baseCardId(card.id), (b) => _better(card, b) ? card : b, ifAbsent: () => card);
  }
  return {for (final card in cards) card.id: best[baseCardId(card.id)]!};
}

bool _better(CardData a, CardData b) =>
    a.rarity.index != b.rarity.index ? a.rarity.index > b.rarity.index : a.id.compareTo(b.id) > 0;

/// A pack source handing out [source]'s packs with every card replaced
/// by its most valuable version (see [bestVersions]), foil kept.
class BestVersionsSource implements PackSource {
  const BestVersionsSource(this.source, this.best);

  final PackSource source;
  final Map<String, CardData> best;

  @override
  List<CardData> nextPack() => [
        for (final card in source.nextPack())
          switch (best[card.id]) {
            final better? when better.id != card.id => card.foil ? better.asFoil() : better,
            _ => card,
          },
      ];
}
