import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/packs/presentation/opening_mode.dart';
import 'package:opack/features/sealed/presentation/sealed_screen.dart';

void main() {
  CardData card(String id, Rarity rarity) => CardData(id: id, names: {'en': id}, rarity: rarity);
  final packs = [
    [card('A1', Rarity.common), card('A2', Rarity.rare)],
    [card('B1', Rarity.common), card('B2', Rarity.mythic), card('B3', Rarity.common)],
  ];
  List<String> ids(SealedOrder order) => [for (final c in sealedOrder(packs, order)) c.card.id];

  test('a sealed deal is revealed pack after pack, slot after slot, or best first', () {
    expect(ids(SealedOrder.byBooster), ['A1', 'A2', 'B1', 'B2', 'B3']);
    expect(ids(SealedOrder.bySlot), ['A1', 'B1', 'A2', 'B2', 'B3'], reason: 'a shorter pack just runs out');
    expect(ids(SealedOrder.byQuality), ['B2', 'A2', 'A1', 'B1', 'B3'], reason: 'ties keep pack and slot order');
    expect(sealedOrder(packs, SealedOrder.bySlot)[1], (pack: 1, slot: 0, card: packs[1][0]));
  });
}
