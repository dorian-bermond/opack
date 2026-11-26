import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_render/ygo_card_face.dart';

YgoCardInfo _info(Map<String, dynamic> json) => YgoCardInfo.fromYgoprodeck({'id': 1, 'name': 'X', 'desc': 'Text.', ...json});

Future<void> _show(WidgetTester tester, YgoCardInfo info,
    {String name = 'Name', String language = 'en', double textScale = 1}) async {
  tester.view.physicalSize = const Size(695, 1013);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    // A system asking for larger text must not change the card.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: YgoCardFace(name: name, info: info, code: 'TEST-EN001', passcode: '2204140', language: language),
  ));
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  final effect = _info({
    'type': 'Effect Monster', 'frameType': 'effect', 'race': 'Zombie', 'attribute': 'EARTH', 'level': 4,
    'atk': 1700, 'def': 800,
  });

  test('the frame follows the kind of card, a pendulum its base frame', () {
    expect(YgoCardFace.frameOf(effect), 'effect');
    expect(YgoCardFace.frameOf(_info({'type': 'Spell Card', 'frameType': 'spell', 'race': 'Field'})), 'spell');
    expect(YgoCardFace.frameOf(_info({'type': 'Trap Card', 'frameType': 'trap', 'race': 'Counter'})), 'trap');
    expect(
      YgoCardFace.frameOf(_info({'type': 'Pendulum Effect Fusion Monster', 'frameType': 'fusion_pendulum', 'race': 'Dragon'})),
      'fusion',
    );
    expect(YgoCardFace.frameOf(_info({'type': 'Normal Monster', 'frameType': 'unknown', 'race': 'Dragon'})), 'normal');
    expect(YgoCardFace.frameOf(_info({'type': 'Effect Monster', 'frameType': 'unknown', 'race': 'Dragon'})), 'effect');
  });

  test('the type line is printed in the card language, unknown words as typed', () {
    expect(YgoCardFace.monsterTypeLine(effect), '[Zombie / Effect]');
    final tuner = _info({'type': 'Tuner Effect Monster', 'frameType': 'effect', 'race': 'Spellcaster'});
    expect(YgoCardFace.monsterTypeLine(tuner, language: 'fr'), '[Magicien / Syntoniseur / Effet]');
    final own = _info({'type': 'Effect Monster', 'frameType': 'effect', 'race': 'My Own Type'});
    expect(YgoCardFace.monsterTypeLine(own, language: 'fr'), '[My Own Type / Effet]');
    expect(YgoCardFace.spellTypeLabel(YgoKind.trap, 'fr'), 'Carte Piège');
    expect(YgoCardFace.spellTypeLabel(YgoKind.spell, 'en'), 'Spell Card');
  });

  test('each bullet of a text starts its own line', () {
    expect(YgoCardFace.printedText('Choose one: ● Draw. ● Discard.'), 'Choose one:\n● Draw.\n● Discard.');
    expect(YgoCardFace.printedText('Plain.\r\nTwo lines.'), 'Plain.\nTwo lines.');
  });

  testWidgets('a monster shows its stars, type line and stats', (tester) async {
    await _show(tester, effect, name: 'Mezuki');
    expect(find.text('Mezuki'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('ygoStar-')),
        findsNWidgets(4));
    expect(find.text('[Zombie / Effect]'), findsOneWidget);
    Finder inStat(String key, String text) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
    expect(inStat('ygoAtk', 'ATK/'), findsOneWidget);
    expect(inStat('ygoAtk', '1700'), findsOneWidget);
    expect(inStat('ygoDef', 'DEF/'), findsOneWidget);
    expect(inStat('ygoDef', '800'), findsOneWidget);
    // The label against the left of its box, the number against the right.
    expect(tester.getTopLeft(inStat('ygoAtk', 'ATK/')).dx, lessThan(tester.getTopLeft(inStat('ygoAtk', '1700')).dx));
    expect(find.text('TEST-EN001'), findsOneWidget);
    expect(find.text('02204140'), findsOneWidget, reason: 'the passcode in eight digits');
    expect(find.byKey(const Key('ygoSpellType')), findsNothing);
  });

  testWidgets('a link monster shows its arrows and rating, no stars nor DEF', (tester) async {
    await _show(
      tester,
      _info({
        'type': 'Link Monster', 'frameType': 'link', 'race': 'Cyberse', 'attribute': 'DARK', 'atk': 2300,
        'linkval': 3, 'linkmarkers': ['Top', 'Bottom-Left', 'Bottom-Right'],
      }),
    );
    for (final marker in ['top', 'bottom-left', 'bottom-right']) {
      expect(find.byKey(ValueKey('ygoArrow-$marker-true')), findsOneWidget);
    }
    for (final marker in ['bottom', 'left', 'right', 'top-left', 'top-right']) {
      expect(find.byKey(ValueKey('ygoArrow-$marker-false')), findsOneWidget);
    }
    expect(find.byKey(const Key('ygoLink')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const Key('ygoDef')), findsNothing);
    expect(find.byKey(const ValueKey('ygoStar-0')), findsNothing);
  });

  testWidgets('a spell shows its kind in the card language, no monster line', (tester) async {
    await _show(tester, _info({'type': 'Spell Card', 'frameType': 'spell', 'race': 'Quick-Play'}), language: 'fr');
    expect(find.text('[Carte Magie'), findsOneWidget);
    expect(find.byKey(const Key('ygoType')), findsNothing);
    expect(find.byKey(const Key('ygoAtk')), findsNothing);
  });

  testWidgets('a very long name and a very long text still fit the card', (tester) async {
    await _show(
      tester,
      _info({
        'type': 'Effect Monster', 'frameType': 'effect', 'race': 'Dragon', 'attribute': 'LIGHT', 'level': 12,
        'atk': 4000, 'def': 4000, 'desc': List.filled(60, 'This effect goes on and on.').join(' '),
      }),
      name: 'The Extremely Long Name of a Card That Would Never Fit Its Line Unsqueezed',
    );
    expect(find.byKey(const Key('ygoText')), findsOneWidget);
  });

  testWidgets('the system text scale leaves the card as printed', (tester) async {
    await _show(tester, effect, name: 'Mezuki');
    final plain = tester.getSize(find.text('Mezuki'));
    final stat = tester.getSize(find.text('1700'));
    await _show(tester, effect, name: 'Mezuki', textScale: 1.5);
    expect(tester.getSize(find.text('Mezuki')), plain);
    expect(tester.getSize(find.text('1700')), stat);
  });

  test('thin texts are thickened on a card shown small, more the smaller it is', () {
    expect(YgoCardFace.thickeningAt(1, Colors.black), isNull, reason: 'as printed at full size');
    expect(YgoCardFace.thickeningAt(0.6, Colors.black), isNull);
    final small = YgoCardFace.thickeningAt(0.25, Colors.black)!;
    final smaller = YgoCardFace.thickeningAt(0.1, Colors.black)!;
    expect(small.first.offset.dx, greaterThan(0));
    expect(smaller.first.offset.dx, greaterThan(small.first.offset.dx));
    // The same share of a screen pixel whatever the size.
    expect(small.first.offset.dx * 0.25, closeTo(smaller.first.offset.dx * 0.1, 1e-9));
  });

  testWidgets('a small card draws its text thickened, a large one as printed', (tester) async {
    TextStyle textStyle() => tester
        .widget<Text>(find.descendant(of: find.byKey(const Key('ygoText')), matching: find.byType(Text)))
        .style!;
    await _show(tester, effect);
    expect(textStyle().shadows, isNotNull, reason: '695 px wide: half the template');
    tester.view.physicalSize = const Size(1389, 2026);
    await tester.pumpAndSettle();
    expect(textStyle().shadows, isNull);
  });

  testWidgets('an unknown stat is printed ?, a typed one as typed', (tester) async {
    await _show(tester, _info({
      'type': 'Effect Monster', 'frameType': 'effect', 'race': 'Zombie', 'attribute': 'EARTH', 'level': 8,
      'atk': -1, 'def': 'X000',
    }));
    expect(find.descendant(of: find.byKey(const Key('ygoAtk')), matching: find.text('?')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('ygoDef')), matching: find.text('X000')), findsOneWidget);
    expect(find.text('-1'), findsNothing);
  });
}
