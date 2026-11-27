import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/domain/ygo_words.dart';
import 'package:opack/features/card_info/presentation/labels.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/l10n/app_localizations_en.dart';
import 'package:opack/l10n/app_localizations_fr.dart';

void main() {
  test('Yu-Gi-Oh! words read in French and come back to English', () {
    expect(ygoWord('fr', 'EARTH'), 'TERRE');
    expect(ygoWord('fr', 'Zombie'), 'Zombie');
    expect(ygoWord('fr', 'Spellcaster'), 'Magicien');
    expect(ygoWord('fr', 'Monster'), 'Monstre');
    expect(ygoWord('fr', 'Quick-Play'), 'Jeu-Rapide');
    expect(ygoWord('en', 'EARTH'), 'EARTH');
    expect(ygoWord('fr', 'My own word'), 'My own word', reason: 'unknown words stay');
    expect(ygoCanonical('fr', 'terre'), 'EARTH');
    expect(ygoCanonical('fr', 'Magicien'), 'Spellcaster');
    expect(ygoCanonical('fr', 'EARTH'), 'EARTH', reason: 'English is taken too');
    expect(ygoCanonical('fr', 'Monstre'), 'Monster');
    expect(ygoCanonical('fr', 'Mon propre mot'), 'Mon propre mot');
    // Every known word has its French one.
    for (final word in [...ygoAttributes, ...ygoMonsterTypes, ...ygoSupertypes, ...ygoSpellTrapKinds]) {
      expect(ygoCanonical('fr', ygoWord('fr', word)), word, reason: word);
    }
  });

  test('labels show a Yu-Gi-Oh! value in the language, other games as is', () {
    final fr = AppLocalizationsFr();
    final en = AppLocalizationsEn();
    expect(valueLabel(fr, 'EARTH', game: Game.ygo), 'TERRE');
    expect(valueLabel(en, 'EARTH', game: Game.ygo), 'EARTH');
    expect(valueLabel(fr, 'Beast', game: Game.mtg), 'Beast', reason: 'a Magic type is no Yu-Gi-Oh! word');
    expect(valueLabel(fr, 'spell:Quick-Play', game: Game.ygo), 'Magie · Jeu-Rapide');
    const info = YgoCardInfo(
        name: 'M', kind: YgoKind.monster, type: 'Effect Monster', frameType: 'effect', race: 'Spellcaster',
        attribute: 'DARK', level: 7, atk: 2500, def: 2100);
    expect(cardInfoLine(info, language: 'fr'), 'TÉNÈBRES · Magicien · ★7 · ATK 2500 / DEF 2100');
    expect(cardInfoLine(info), 'DARK · Spellcaster · ★7 · ATK 2500 / DEF 2100');
  });

  test('a monster with an effect its type does not name prints Effect', () {
    final tuner = YgoCardInfo.fromYgoprodeck(const {
      'name': 'Plaguespreader Zombie', 'type': 'Tuner Monster', 'frameType': 'effect', 'race': 'Zombie',
      'attribute': 'DARK', 'level': 2, 'misc_info': [{'has_effect': 1}],
    });
    expect(tuner.categories, ['Tuner', 'Effect']);
    expect(YgoCardInfo.fromJson(tuner.toJson()).categories, ['Tuner', 'Effect']);
    // A card cached from before carries no Effect: it is told from the flag.
    final cached = YgoCardInfo.fromJson({...tuner.toJson(), 'categories': ['Tuner']});
    expect(cached.categories, ['Tuner', 'Effect']);
    final normal = YgoCardInfo.fromYgoprodeck(const {
      'name': 'N', 'type': 'Normal Tuner Monster', 'frameType': 'normal', 'race': 'Zombie',
      'misc_info': [{'has_effect': 0}],
    });
    expect(normal.categories, ['Normal', 'Tuner']);
  });
}
