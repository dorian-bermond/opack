import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/shared/widgets/set_icon.dart';

void main() {
  const hobbit = SetSummary(
    code: 'HOB',
    game: Game.mtg,
    names: {'en': 'The Hobbit'},
    boosterTypes: [BoosterType.play],
    cardCount: 418,
    assetPath: 'assets/sets/mtg/HOB.json',
    icon: 'assets/sets/mtg/icons/HOB.svg',
  );
  const mystery = SetSummary(
    code: 'MB1',
    game: Game.mtg,
    names: {'en': 'Mystery Booster'},
    boosterTypes: [BoosterType.play],
    cardCount: 1,
    assetPath: 'assets/sets/mtg/MB1.json',
  );

  testWidgets('a set with a symbol shows it, one without shows its code', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Row(children: [
        SetSymbol(hobbit, code: 'HOB', size: 28),
        SetSymbol(mystery, code: 'MB1', size: 28),
        SetSymbol(null, code: 'OP18', size: 28),
      ]),
    ));
    expect(find.byKey(const Key('setSymbol')), findsOneWidget);
    expect(find.byKey(const Key('setCode')), findsNWidgets(2));
    expect(find.text('MB1'), findsOneWidget);
    expect(find.text('OP18'), findsOneWidget, reason: 'the code given when the set is unknown');
    expect(SetSummary.fromJson(const {
      'code': 'HOB', 'game': 'mtg', 'names': {'en': 'x'}, 'boosterTypes': ['play'], 'cardCount': 1,
      'path': 'p', 'icon': 'assets/sets/mtg/icons/HOB.svg',
    }).icon, 'assets/sets/mtg/icons/HOB.svg');
  });
}
