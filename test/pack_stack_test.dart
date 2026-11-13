import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/packs/presentation/pack_stack.dart';
import 'package:opack/l10n/app_localizations.dart';
import 'package:opack/shared/images/card_image_cache.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/shared/widgets/card_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cards = [
  CardData(id: 'T-1', names: {'en': 'First'}, rarity: Rarity.common),
  CardData(id: 'T-2', names: {'en': 'Second'}, rarity: Rarity.rare),
  CardData(id: 'T-3', names: {'en': 'Third'}, rarity: Rarity.mythic),
];

Future<Widget> _app(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
      overrides: [
        cardImageCacheProvider.overrideWithValue(null),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
}

void main() {
  testWidgets('swiping or tapping the top card away uncovers the next, then the grid', (tester) async {
    await tester.pumpWidget(await _app(const PackStack(cards: _cards)));
    expect(find.text('3 cards left'), findsOneWidget);

    // A short drag springs back.
    await tester.drag(find.byKey(const ValueKey('stackTop0')), const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(find.text('3 cards left'), findsOneWidget);

    await tester.drag(find.byKey(const ValueKey('stackTop0')), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 cards left'), findsOneWidget);
    expect(find.byKey(const ValueKey('stackTop1')), findsOneWidget);

    // A plain tap counts as a swipe.
    await tester.tap(find.byKey(const ValueKey('stackTop1')));
    await tester.pumpAndSettle();
    expect(find.text('1 card left'), findsOneWidget);
    expect(find.byKey(const ValueKey('stackTop2')), findsOneWidget);

    await tester.drag(find.byKey(const ValueKey('stackTop2')), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(CardGrid), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
  });

  testWidgets('removing a hovered face-down card does not break the tree', (tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    var shown = true;
    late StateSetter rebuild;
    await tester.pumpWidget(await _app(StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return shown
          ? SizedBox(width: 120, height: 170, child: CardTile(card: _cards[0], revealed: false))
          : const SizedBox();
    })));
    await mouse.moveTo(tester.getCenter(find.byType(CardTile)));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration, isA<BoxDecoration>()
        .having((d) => d.boxShadow, 'glow', isNotEmpty));

    rebuild(() => shown = false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CardTile), findsNothing);
  });
}