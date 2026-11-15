import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/l10n/app_localizations.dart';
import 'package:opack/shared/images/card_image_cache.dart';
import 'package:opack/shared/widgets/card_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _card = CardData(id: 'DMU-1', names: {'en': 'A'}, rarity: Rarity.rare, scryfallId: 'abc');

/// A 1×1 transparent PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00, //
  0x00, 0x05, 0x00, 0x01, 0xE2, 0x26, 0x05, 0x9B, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, //
  0xAE, 0x42, 0x60, 0x82,
]);

Future<(Widget, ProviderContainer)> _app(File image) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    cardImageCacheProvider.overrideWithValue(null),
    sharedPreferencesProvider.overrideWithValue(prefs),
    cardImageProvider.overrideWith((ref, source) async => image),
  ]);
  return (
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 120, height: 170, child: CardTile(card: _card)),
          ),
        ),
      ),
    ),
    container,
  );
}

void main() {
  testWidgets('hovering a card for a moment shows it large, until the pointer leaves', (tester) async {
    final image = File('${Directory.systemTemp.path}/opack-hover-${DateTime.now().microsecondsSinceEpoch}.png');
    // Real file I/O only completes outside the test's fake time.
    await tester.runAsync(() => image.writeAsBytes(_png));
    addTearDown(image.deleteSync);
    final (app, container) = await _app(image);
    addTearDown(container.dispose);
    // The picture is read from disk, real I/O that fake time cannot await.
    await tester.runAsync(() async {
      await tester.pumpWidget(app);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.byType(Image), findsOneWidget, reason: 'the tile shows the picture');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(60, 85));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('cardPreview')), findsNothing, reason: 'not yet: the pointer must rest');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('cardPreview')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('cardPreview'))).width, 360);

    await mouse.moveTo(const Offset(500, 500));
    await tester.pump();
    expect(find.byKey(const Key('cardPreview')), findsNothing);

    // Off by the setting, hovering shows nothing.
    container.read(cardHoverPreviewProvider.notifier).set(false);
    await tester.pump();
    await mouse.moveTo(const Offset(60, 85));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('cardPreview')), findsNothing);
  });

  testWidgets('the rarity shows as a colored border, or as a dot by the setting', (tester) async {
    final image = File('${Directory.systemTemp.path}/opack-dot-${DateTime.now().microsecondsSinceEpoch}.png');
    await tester.runAsync(() => image.writeAsBytes(_png));
    addTearDown(image.deleteSync);
    final (app, container) = await _app(image);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await tester.pumpWidget(app);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    BorderSide side() => (tester.widget<Card>(find.byType(Card)).shape! as RoundedRectangleBorder).side;
    expect(side().color, Rarity.rare.color);
    expect(side().width, 3);
    expect(find.byKey(const Key('rarityDot')), findsNothing);

    container.read(rarityMarkerProvider.notifier).select(RarityMarker.dot);
    await tester.pump();
    expect(find.byKey(const Key('rarityDot')), findsOneWidget);
    expect(side().width, 1);
    expect(side().color, isNot(Rarity.rare.color));
    // A framed card (a tierlist value) wears the frame's color, no marker.
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 120, height: 170, child: CardTile(card: _card, frameColor: Colors.green)),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const Key('rarityDot')), findsNothing);
    expect(side().color, Colors.green);
    expect(side().width, 6);

    await tester.pumpWidget(app);
    await tester.pump();
    final dot = tester.getRect(find.byKey(const Key('rarityDot')));
    final tile = tester.getRect(find.byType(CardTile));
    expect(dot.center.dx, closeTo(tile.center.dx, 1), reason: 'centered');
    expect(dot.bottom, closeTo(tile.bottom - 5 - 3, 2), reason: 'at the bottom, inside the border');
  });
}
