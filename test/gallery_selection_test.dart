import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/features/card_text/domain/card_text.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/presentation/marquee_selection.dart';
import 'package:opack/features/pools/presentation/pool_view.dart';
import 'package:opack/l10n/app_localizations.dart';
import 'package:opack/shared/images/card_image_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const a = CardData(id: 'X-1', names: {'en': 'Alpha'}, rarity: Rarity.rare);
  const b = CardData(id: 'X-2', names: {'en': 'Beta'}, rarity: Rarity.common);

  testWidgets('in the gallery a tap selects cards and a right-click opens their operations', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final selected = <String>{};
    final menus = <(String, Offset)>[];
    var tagging = false;
    final tagged = <String>[];

    late StateSetter rebuild;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cardImageCacheProvider.overrideWithValue(null),
        cardTextsProvider.overrideWith((ref) async => <String, CardTexts>{}),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            rebuild = setState;
            return CustomScrollView(slivers: [
              PoolGallerySliver(
                items: [
                  for (final card in [a, b]) (card: card, info: null, tags: const <String>{}),
                ],
                actions: PoolCardActions(
                  copiesOf: (_) => 1,
                  listedOf: (_) => 1,
                  changed: (_) => false,
                  setCopies: (_, _) {},
                  tint: (_) => null,
                  onTags: (_) {},
                  tagsOf: (_) => const [],
                  onTap: tagging ? (card) => tagged.add(card.id) : null,
                  selected: (card) => selected.contains(card.id),
                  onSelect: (card) =>
                      setState(() => selected.contains(card.id) ? selected.remove(card.id) : selected.add(card.id)),
                  onMenu: (card, position) => menus.add((card.id, position)),
                ),
              ),
            ]);
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Taps add to the selection, and take out of it.
    await tester.tap(find.text('Alpha'));
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(selected, {'X-1', 'X-2'});
    expect(find.byKey(const ValueKey('selected-X-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-X-2')), findsOneWidget);
    expect(find.text('Unlimited copies'), findsNothing, reason: 'no copies sheet on a tap');
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(selected, {'X-2'});
    expect(find.byKey(const ValueKey('selected-X-1')), findsNothing);

    // A right-click asks for the menu where the pointer is; a long-press too.
    final at = tester.getCenter(find.text('Beta'));
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(menus, [('X-2', at)]);
    await tester.longPress(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(menus.last.$1, 'X-1');

    // Bulk tagging keeps the tap, and hides the selection meanwhile.
    rebuild(() => tagging = true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(tagged, ['X-1']);
    expect(selected, {'X-2'});
    expect(find.byKey(const ValueKey('selected-X-2')), findsNothing);
  });

  testWidgets('holding the mouse button draws a rectangle selecting the cards it touches', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cards = [
      for (var i = 0; i < 40; i++) CardData(id: 'X-$i', names: {'en': 'Card $i'}, rarity: Rarity.common),
    ];
    final selected = <String>{};
    var base = <String>{};
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cardImageCacheProvider.overrideWithValue(null),
        cardTextsProvider.overrideWith((ref) async => <String, CardTexts>{}),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            void toggle(String id) =>
                setState(() => selected.contains(id) ? selected.remove(id) : selected.add(id));
            return MarqueeSelection(
              controller: scroll,
              enabled: true,
              onStart: (additive) => base = additive ? {...selected} : {},
              onHits: (ids) => setState(() => selected
                ..clear()
                ..addAll(base)
                ..addAll(ids)),
              onClick: (id) => id == null ? setState(selected.clear) : toggle(id),
              child: CustomScrollView(controller: scroll, slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 100, child: Text('header'))),
                PoolGallerySliver(
                  columns: 4,
                  items: [for (final card in cards) (card: card, info: null, tags: const <String>{})],
                  actions: PoolCardActions(
                    copiesOf: (_) => 1,
                    listedOf: (_) => 1,
                    changed: (_) => false,
                    setCopies: (_, _) {},
                    tint: (_) => null,
                    onTags: (_) {},
                    tagsOf: (_) => const [],
                    selected: (card) => selected.contains(card.id),
                    onSelect: (card) => toggle(card.id),
                    onMenu: (_, _) {},
                  ),
                ),
              ]),
            );
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    Offset center(int i) => tester.getCenter(find.text('Card $i'));
    // One mouse for the whole test.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    Future<TestGesture> press(Offset at) async {
      await mouse.moveTo(at);
      await mouse.down(at);
      await tester.pump();
      return mouse;
    }

    // From the first card to the sixth (second row, second column): the
    // four cards of that block, the rectangle shown meanwhile.
    var gesture = await press(center(0));
    await gesture.moveTo(center(1));
    await gesture.moveTo(center(5));
    await tester.pump();
    expect(find.byKey(const Key('marquee')), findsOneWidget);
    expect(selected, {'X-0', 'X-1', 'X-4', 'X-5'});
    // Shrinking it lets cards go.
    await gesture.moveTo(center(1));
    await tester.pump();
    expect(selected, {'X-0', 'X-1'});
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('marquee')), findsNothing);
    expect(selected, {'X-0', 'X-1'}, reason: 'releasing keeps the selection, and taps no card');

    // A new rectangle replaces the selection.
    gesture = await press(center(2));
    await gesture.moveTo(center(3));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, {'X-2', 'X-3'});

    // A plain click still selects one more card; one on the header does nothing.
    gesture = await press(center(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, {'X-0', 'X-2', 'X-3'});
    gesture = await press(tester.getCenter(find.text('header')));
    await gesture.moveBy(const Offset(200, 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('marquee')), findsNothing);
    expect(selected, {'X-0', 'X-2', 'X-3'}, reason: 'no rectangle starts above the cards');

    // The wheel scrolls under a held rectangle, which keeps what it caught.
    gesture = await press(center(0));
    await gesture.moveTo(center(1));
    await tester.pump();
    expect(selected, {'X-0', 'X-1'});
    for (var to = 100.0; to < scroll.position.maxScrollExtent; to += 100) {
      scroll.jumpTo(to);
      await tester.pump();
    }
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(selected.containsAll({'X-0', 'X-1', 'X-5'}), isTrue, reason: 'the rectangle grew with the scroll');
    expect(selected.length, greaterThan(8));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
