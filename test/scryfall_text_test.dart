import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_text/data/scryfall_text.dart';
import 'package:opack/features/catalog/domain/models.dart';

void main() {
  test('reads printed wording, flavor text and both faces', () {
    final single = ScryfallText.fromJson({
      'name': 'Karn, Living Legacy',
      'printed_name': 'Karn, héritage vivant',
      'type_line': 'Legendary Planeswalker — Karn',
      'mana_cost': '{4}',
      'oracle_text': '+1: Create a tapped Powerstone token.',
      'flavor_text': 'A legacy.',
    });
    expect(single.faces, hasLength(1));
    expect(single.faces.single.name, 'Karn, héritage vivant');
    expect(single.faces.single.text, '+1: Create a tapped Powerstone token.');
    expect(single.faces.single.flavor, 'A legacy.');

    final twoFaced = ScryfallText.fromJson({
      'name': 'Bereaved Survivor // Dauntless Avenger',
      'card_faces': [
        {'name': 'Bereaved Survivor', 'printed_text': 'Quand une autre créature meurt…'},
        {'name': 'Dauntless Avenger', 'oracle_text': 'Whenever this attacks…'},
      ],
    });
    expect(twoFaced.faces.map((f) => f.name), ['Bereaved Survivor', 'Dauntless Avenger']);
    expect(twoFaced.faces.first.text, 'Quand une autre créature meurt…');
  });

  test('a French request falls back to the English print', () {
    const card = CardData(id: 'DMU-1', names: {}, rarity: Rarity.rare, scryfallId: 'abc');
    final fr = scryfallTextSource(card, language: 'fr')!;
    expect(fr.key, 'text-scryfall-abc-fr');
    expect(fr.url.path, '/cards/dmu/1/fr');
    expect(fr.fallback!.url.path, '/cards/abc');
    expect(scryfallTextSource(card)!.key, 'text-scryfall-abc');
    expect(scryfallTextSource(const CardData(id: 'X', names: {}, rarity: Rarity.common)), isNull);
  });
}
