import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/app.dart';
import 'package:opack/core/router.dart';
import 'package:opack/core/settings/locale_controller.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/features/card_info/data/card_info_repository.dart';
import 'package:opack/features/card_info/data/card_search.dart';
import 'package:opack/features/card_info/presentation/search_panel.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_info/presentation/card_search_sheet.dart';
import 'package:opack/features/catalog/data/catalog_repository.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/cube/data/cube_repository.dart';
import 'package:opack/features/cube/domain/cube.dart';
import 'package:opack/features/pools/data/pool_repository.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/shared/widgets/card_tile.dart';
import 'package:opack/features/pools/presentation/pool_view.dart';
import 'package:opack/features/pools/presentation/tierlist_screen.dart';
import 'package:opack/shared/images/artwork_search.dart';
import 'package:opack/shared/images/card_image_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the app on the real bundled catalog, in [locale] or else the
/// device language.
/// With [cardSearch], online search is on (through its mock client).
Future<ProviderContainer> startApp(WidgetTester tester, {Locale? locale, CardSearch? cardSearch}) async {
  // A tall window so the editor's long header and its card list fit at once.
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final (catalog, prefs) = (await tester.runAsync(
    () => (AssetCatalogRepository.load(rootBundle), SharedPreferences.getInstance()).wait,
  ))!;
  final container = ProviderContainer(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(catalog),
      sharedPreferencesProvider.overrideWithValue(prefs),
      poolStoreProvider.overrideWithValue(MemoryPoolStore()),
      cubeStoreProvider.overrideWithValue(MemoryCubeStore()),
      cardImageCacheProvider.overrideWithValue(null),
      cardInfoFetcherProvider.overrideWithValue(null),
      cardInfoStoreProvider.overrideWithValue(MemoryCardInfoStore()),
      cardSearchProvider.overrideWithValue(cardSearch),
      artworkSearchProvider.overrideWithValue(null),
    ],
  );
  addTearDown(container.dispose);
  if (locale != null) container.read(localeProvider.notifier).select(locale);
  router.go('/');

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const OpackApp(),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// Lets sets, cubes and pools finish loading (asset reads are real I/O).
Future<void> settleLoading(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

/// From the pools screen, creates a Yu-Gi-Oh! pool from the set matching
/// [search] and lands in its editor.
Future<void> createPoolFromSet(WidgetTester tester, String search,
    {required String newPool, required String fromSet}) async {
  await tester.tap(find.text(newPool));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Yu-Gi-Oh!'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(fromSet));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(SearchBar), search);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ListTile).first);
  await settleLoading(tester);
}

void main() {
  testWidgets('French: a pool from a set, then a pack opened from it', (tester) async {
    await startApp(tester, locale: const Locale('fr'));
    expect(find.textContaining('Aucun pool'), findsOneWidget);

    await createPoolFromSet(tester, 'coupe-circuit',
        newPool: 'Nouveau pool', fromSet: "À partir d'une extension");
    expect(find.text('Le Coupe-Circuit'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir un booster'));
    await settleLoading(tester);
    await tester.tap(find.byKey(const Key('sealedPack')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout révéler'));
    await tester.pumpAndSettle();

    // The grid builds lazily, so only the visible cards are in the tree.
    expect(find.textContaining('CIBR-FR'), findsWidgets);
  });

  testWidgets('English: create a pool from a set, edit it, play it', (tester) async {
    await startApp(tester, locale: const Locale('en'));
    expect(find.text('Opack'), findsOneWidget);
    await createPoolFromSet(tester, 'circuit', newPool: 'New pool', fromSet: 'From a set');
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Cards from'), findsNothing, reason: 'sources live on the details page');

    // The details page holds the sources, tags and copies.
    await tester.tap(find.byTooltip('Pool details'));
    await tester.pumpAndSettle();
    expect(find.text('Cards from'), findsOneWidget);
    expect(find.text('Unlimited packs'), findsOneWidget);
    await tester.tap(find.text('Closed'));
    await tester.pumpAndSettle();
    expect(find.text('1 × each card'), findsOneWidget);
    expect(find.textContaining('of 9 cards available'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Every view shows the same cards; the stacks group them by rarity.
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(CardTile), findsWidgets);
    expect(find.textContaining('×'), findsWidgets);
    await tester.tap(find.text('Stacks'));
    await tester.pumpAndSettle();
    // The stacks column header (the layout tag chip is on the details page).
    expect(find.textContaining('Secret rare · '), findsOneWidget);
    await tester.tap(find.text('Spoiler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CIBR-FR0'), findsWidgets);
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    // Tag a card in bulk, pull one such card per pack, then drop the slot.
    await tester.tap(find.byTooltip('Pool details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'mine');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('mine · 0'), findsOneWidget);
    // Tapping the tag opens the editor to pick its cards.
    await tester.tap(find.text('mine · 0'));
    await settleLoading(tester);
    expect(find.text('Tagging: mine'), findsOneWidget);
    // Tap a card row that is on screen (the last built one may lie below).
    await tester.tap(find.ancestor(of: find.textContaining('CIBR-FR0'), matching: find.byType(ListTile)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Tagging: mine'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('mine · 1'), findsOneWidget, reason: 'the chip on the details page');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Group the list by tag: the tagged card sits under its own header.
    await tester.tap(find.byTooltip('Group by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tag').last);
    await tester.pumpAndSettle();
    expect(find.text('mine · 1'), findsOneWidget, reason: 'the group header');
    // Headers fold their section.
    expect(find.byIcon(Icons.expand_more), findsNothing);
    await tester.tap(find.text('mine · 1').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_more), findsOneWidget, reason: 'the mine group is folded');
    await tester.tap(find.text('mine · 1').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_more), findsNothing);
    // A secondary grouping nests rarity sections under each tag.
    await tester.tap(find.byTooltip('Then by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rarity').last);
    await tester.pumpAndSettle();
    expect(find.text('Secret rare · 1'), findsOneWidget, reason: 'the rarity section inside the mine group');
    await tester.tap(find.byTooltip('Group by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No grouping'));
    await tester.pumpAndSettle();

    // A layout tag is editable too: drop one card from the commons.
    await tester.tap(find.byTooltip('Pool details'));
    await tester.pumpAndSettle();
    final commonChip =
        find.descendant(of: find.byType(InputChip), matching: find.textContaining(RegExp(r'^Common · '))).first;
    expect(commonChip, findsOneWidget);
    await tester.tap(commonChip);
    await settleLoading(tester);
    expect(find.text('Tagging: common'), findsOneWidget);
    await tester.tap(find.ancestor(of: find.textContaining('CIBR-FR0'), matching: find.byType(ListTile)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^Common · ')), findsNWidgets(2), reason: 'the sheet tag and the rarity value');

    // Deleting a tag warns about the slots pulling from it.
    final commonChipWidget = find.ancestor(of: commonChip, matching: find.byType(InputChip));
    await tester.tap(find.descendant(of: commonChipWidget, matching: find.byTooltip('Delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete the tag Common?'), findsOneWidget);
    expect(find.textContaining('7 × Common'), findsNWidgets(2), reason: 'the composition and the warning');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(commonChip, findsOneWidget);

    // The composition is edited from the details page too.
    await tester.tap(find.text('Edit composition'));
    await settleLoading(tester);
    expect(find.textContaining('7 × Common'), findsOneWidget, reason: 'the prefilled common slot');
    await tester.tap(find.text('Add a slot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add an option'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    // The dialog starts on the first tag, the prefilled common one.
    expect(find.text('1 × Common 1/2 · Common 1/2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('1 × Common 1/2 · Common 1/2'), findsNothing);
    expect(find.textContaining('7 × Common'), findsOneWidget, reason: 'the prefilled slots stay');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Booster composition'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget, reason: 'back in the editor');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Circuit Break'), findsOneWidget);
    expect(find.text('Closed ×1'), findsOneWidget);

    await tester.tap(find.text('Sealed'));
    await settleLoading(tester);
    expect(find.text('Sealed pool'), findsOneWidget);
    expect(find.textContaining('Closed ×1 · 5 packs · 45 cards'), findsOneWidget);
  });

  testWidgets('the search panel adds and removes found cards beside the pool', (tester) async {
    final search = CardSearch(
      client: MockClient((request) async {
        expect(request.url.host, 'db.ygoprodeck.com');
        expect(request.url.queryParameters['fname'], 'mock');
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 12345678,
              'name': 'Mock Dragon',
              'type': 'Effect Monster',
              'frameType': 'effect',
              'race': 'Dragon',
              'attribute': 'LIGHT',
              'level': 8,
              'atk': 3000,
              'def': 2500,
              'desc': 'A mock.',
              'card_sets': [
                {'set_code': 'MOCK-EN001', 'set_rarity': 'Ultra Rare'},
              ],
            },
          ],
        }), 200);
      }),
    );
    await startApp(tester, locale: const Locale('en'), cardSearch: search);
    await tester.tap(find.text('New pool'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yu-Gi-Oh!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty pool'));
    await settleLoading(tester);

    // The + icon opens the panel on the right; the pool stays on the left.
    await tester.tap(find.byKey(const Key('searchPanelToggle')));
    await tester.pumpAndSettle();
    expect(find.text('Search cards to add'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget, reason: 'the pool is still shown');
    expect(find.text('Add cards'), findsNothing, reason: 'the chip moved into the panel');

    await tester.enterText(find.byKey(const Key('panelSearch')), 'mock');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Mock Dragon'), findsOneWidget);
    expect(find.text('1 card'), findsOneWidget);

    // Tapping the add icon puts the card in the pool, shown on both sides.
    await tester.tap(find.byKey(const ValueKey('result-MOCK-EN001')));
    await settleLoading(tester);
    expect(find.text('Mock Dragon'), findsNWidgets(2));
    expect(find.textContaining('In the pool'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('result-MOCK-EN001')));
    await settleLoading(tester);
    expect(find.text('Mock Dragon'), findsOneWidget);

    // In gallery mode each side has its own cards-per-row setting.
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('auto'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('moreColumns-pool')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moreColumns-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moreColumns-search')));
    await tester.pumpAndSettle();
    expect(find.text('auto'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fewerColumns-pool')));
    await tester.pumpAndSettle();
    expect(find.text('auto'), findsOneWidget);
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    // The splitter widens the panel when dragged left.
    double panelWidth() => tester.getSize(find.byType(SearchPanel)).width;
    final before = panelWidth();
    await tester.drag(find.byKey(const Key('panelSplitter')), const Offset(-120, 0));
    await tester.pumpAndSettle();
    // Touch slop eats the first few pixels of the drag.
    expect(panelWidth(), inInclusiveRange(before + 90, before + 120));

    // The former Add cards page is the panel's advanced search.
    await tester.tap(find.byKey(const Key('advancedSearch')));
    await tester.pumpAndSettle();
    expect(find.text('Search cards online'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Search cards to add'), findsNothing);
  });

  testWidgets('tag baskets: drag a card onto a tag, undo with Ctrl+Z', (tester) async {
    await startApp(tester, locale: const Locale('en'));
    await createPoolFromSet(tester, 'circuit', newPool: 'New pool', fromSet: 'From a set');

    // Cards are not draggable until basket mode is on.
    expect(find.byKey(const ValueKey('drag-CIBR-FR000')), findsNothing);
    await tester.tap(find.byKey(const Key('basketsToggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('basket-rarity:rare')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('basket-rarity:rare')), matching: find.text('Rare · 20')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('undoDrop'))).enabled, isFalse);

    // Drop a secret rare card into the rare basket.
    final card = find.byKey(const ValueKey('drag-CIBR-FR042'));
    expect(card, findsOneWidget);
    final from = tester.getCenter(card);
    final to = tester.getCenter(find.byKey(const ValueKey('basket-rarity:rare')));
    await tester.timedDrag(card, to - from, const Duration(milliseconds: 400));
    await settleLoading(tester);
    expect(find.descendant(of: find.byKey(const ValueKey('basket-rarity:rare')), matching: find.text('Rare · 21')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('undoDrop'))).enabled, isTrue);

    // Ctrl+Z puts the pool back as it was.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleLoading(tester);
    expect(find.descendant(of: find.byKey(const ValueKey('basket-rarity:rare')), matching: find.text('Rare · 20')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('undoDrop'))).enabled, isFalse);

    await tester.tap(find.byKey(const Key('basketsToggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('basket-rarity:rare')), findsNothing);
  });

  testWidgets('tierlist: drag cards between tiers and the feed, undo with Ctrl+Z', (tester) async {
    final container = await startApp(tester, locale: const Locale('en'));
    await createPoolFromSet(tester, 'circuit', newPool: 'New pool', fromSet: 'From a set');
    await tester.tap(find.byKey(const Key('tierlistButton')));
    await settleLoading(tester);

    // The set's rarities are the first quality: one tier each, no card unvalued.
    expect(find.text('Quality: Rarity'), findsOneWidget);
    expect(find.text('Cards: All cards'), findsOneWidget);
    final rare = find.byKey(const ValueKey('tier-rarity:rare'));
    final secret = find.byKey(const ValueKey('tier-rarity:secretRare'));
    expect(rare, findsOneWidget);
    expect(find.descendant(of: rare, matching: find.text('20')), findsOneWidget);
    expect(find.descendant(of: secret, matching: find.text('8')), findsOneWidget);
    expect(find.textContaining('take the value away. Ctrl+Z undoes. · 0'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('tierlistUndo'))).onPressed, isNull);

    // A secret rare card dragged to the Rare tier changes value.
    final card = find.descendant(of: secret, matching: find.byKey(const ValueKey('drag-CIBR-FR042')));
    expect(card, findsOneWidget);
    await tester.timedDrag(card, tester.getCenter(rare) - tester.getCenter(card), const Duration(milliseconds: 400));
    await settleLoading(tester);
    expect(find.descendant(of: rare, matching: find.text('21')), findsOneWidget);
    expect(find.descendant(of: secret, matching: find.text('7')), findsOneWidget);

    // Dropped on the feed, it loses its value.
    final moved = find.descendant(of: rare, matching: find.byKey(const ValueKey('drag-CIBR-FR042')));
    final feed = find.byKey(const Key('tierlistFeed'));
    await tester.timedDrag(moved, tester.getCenter(feed) - tester.getCenter(moved), const Duration(milliseconds: 400));
    await settleLoading(tester);
    expect(find.descendant(of: rare, matching: find.text('20')), findsOneWidget);
    expect(find.textContaining('take the value away. Ctrl+Z undoes. · 1'), findsOneWidget);
    expect(find.descendant(of: feed, matching: find.byKey(const ValueKey('drag-CIBR-FR042'))), findsOneWidget);

    // Ctrl+Z twice walks both drops back.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleLoading(tester);
    expect(find.descendant(of: rare, matching: find.text('21')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tierlistUndo')));
    await settleLoading(tester);
    expect(find.descendant(of: secret, matching: find.text('8')), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('tierlistUndo'))).onPressed, isNull);

    // Dropping a card on another ranks it right before that one.
    final first = find.descendant(of: rare, matching: find.byType(DraggableCard)).first;
    final firstId = tester.widget<DraggableCard>(first).card.id;
    final third = find.descendant(of: rare, matching: find.byType(DraggableCard)).at(2);
    final thirdId = tester.widget<DraggableCard>(third).card.id;
    await tester.timedDrag(third, tester.getCenter(first) - tester.getCenter(third), const Duration(milliseconds: 400));
    await settleLoading(tester);
    final ranked = [
      for (final w in tester.widgetList<DraggableCard>(find.descendant(of: rare, matching: find.byType(DraggableCard))))
        w.card.id,
    ];
    expect(ranked.take(2), [thirdId, firstId]);
    await tester.tap(find.byKey(const Key('tierlistUndo')));
    await settleLoading(tester);

    // Tiers rank by their arrows; the first cannot go up.
    double top(Finder tier) => tester.getTopLeft(tier).dy;
    // Each tier row wears its value's color: a rarity's usual one when unset.
    Color rowColor(String label) =>
        (tester.widget<AnimatedContainer>(find.byKey(ValueKey('tierRow-$label'))).decoration! as BoxDecoration).color!;
    expect(rowColor('Secret rare'), Rarity.secretRare.color.withValues(alpha: 0.5), reason: 'the marker color');
    expect(rowColor('Ultra rare'), Rarity.ultraRare.color.withValues(alpha: 0.5));
    expect(find.byKey(const Key('rarityDot')), findsNothing);

    // Rarities read best first: secret rare on top, common at the bottom.
    final common = find.byKey(const ValueKey('tier-rarity:common'));
    expect(find.text('Best first'), findsOneWidget);
    expect(top(secret), lessThan(top(rare)));
    expect(top(rare), lessThan(top(common)));
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('tierDown-Common'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('tierUp-Common')));
    await settleLoading(tester);
    expect(top(common), lessThan(top(rare)), reason: 'moved up one row as shown');
    await tester.tap(find.byKey(const Key('tierlistUndo')));
    await settleLoading(tester);
    expect(top(rare), lessThan(top(common)));
    // The order flips for the whole quality, and flips back by undo.
    await tester.tap(find.byKey(const Key('tierlistOrder')));
    await settleLoading(tester);
    expect(find.text('Lowest first'), findsOneWidget);
    expect(top(common), lessThan(top(secret)));
    await tester.tap(find.byKey(const Key('tierlistUndo')));
    await settleLoading(tester);
    expect(top(secret), lessThan(top(common)));

    // A new quality comes with its ranked values and becomes the current one.
    await tester.tap(find.byKey(const Key('tierlistQuality')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New quality…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('qualityNameField')), 'Power');
    await tester.enterText(find.byKey(const ValueKey('qualityValue-0')), 'S');
    await tester.enterText(find.byKey(const ValueKey('qualityValue-1')), 'A');
    await tester.enterText(find.byKey(const ValueKey('qualityValue-2')), 'B');
    await tester.tap(find.text('Apply'));
    await settleLoading(tester);
    expect(find.text('Quality: Power'), findsOneWidget);
    expect(find.byKey(const ValueKey('tier-power:S')), findsOneWidget);
    expect(top(find.byKey(const ValueKey('tier-power:S'))), lessThan(top(find.byKey(const ValueKey('tier-power:B')))));
    expect(container.read(poolsProvider).value!.single.tags['power:S']!.color, 0xFFE53935, reason: 'the first palette color');
    expect(find.textContaining('Ctrl+Z undoes. · 0'), findsNothing, reason: 'nothing valued yet: all in the feed');
    await tester.tap(find.byKey(const Key('tierlistQuality')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rarity'));
    await tester.pumpAndSettle();

    // The size slider scales every card of the tiers and the feed.
    double cardWidth() => tester.getSize(find.descendant(of: rare, matching: find.byType(DraggableCard)).first).width;
    expect(cardWidth(), 96);
    expect(tester.widget<Slider>(find.byKey(const Key('tierlistCardSize'))).value, 96);
    container.read(tierlistCardWidthProvider.notifier).set(120);
    await tester.pumpAndSettle();
    expect(cardWidth(), 120);
    expect(tester.widget<Slider>(find.byKey(const Key('tierlistCardSize'))).value, 120);

    // The feed folds to its header and resizes by its top edge.
    final feedZone = find.byKey(const Key('tierlistFeed'));
    final feedBefore = tester.getSize(feedZone).height;
    await tester.tap(find.byKey(const Key('feedToggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(feedZone).height, lessThan(feedBefore - 80));
    await tester.tap(find.byKey(const Key('feedToggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(feedZone).height, feedBefore);
    await tester.drag(find.byKey(const Key('feedResizer')), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getSize(feedZone).height, greaterThan(feedBefore + 60));

    // A new tier is a new value of the quality (the button sits under the tiers).
    await tester.scrollUntilVisible(find.byKey(const Key('addTier')), 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addTier')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('valueNameField')), 'bonus');
    await tester.tap(find.byKey(ValueKey('swatch-${const Color(0xFF1E88E5).toARGB32()}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await settleLoading(tester);
    expect(find.byKey(const ValueKey('tier-rarity:bonus')), findsOneWidget);
    expect(container.read(poolsProvider).value!.single.tags['rarity:bonus']!.color, 0xFF1E88E5);
  });

  testWidgets('an empty pool cannot be played until it has a source', (tester) async {
    await startApp(tester, locale: const Locale('en'));

    await tester.tap(find.text('New pool'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yu-Gi-Oh!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty pool'));
    await settleLoading(tester);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Add a set or cube'), findsNothing, reason: 'sources are added from the details page');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('No cards yet'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Open a pack').first).enabled,
      isFalse,
    );

    await tester.tap(find.text('Pool details'));
    await settleLoading(tester);
    await tester.tap(find.text('Add a set or cube'));
    await tester.pumpAndSettle();
    // The editor has its own card search bar; the dialog's is on top.
    await tester.enterText(find.byType(SearchBar).last, 'circuit');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(ListTile)).first);
    await settleLoading(tester);
    expect(find.text('Circuit Break (CIBR)'), findsOneWidget);
  });

  testWidgets('follows the device language when none is chosen', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await startApp(tester);
    expect(find.text('Nouveau pool'), findsOneWidget);
  });
}

/// Keeps saved pools in memory, as widget tests have no app directory.
class MemoryPoolStore extends PoolStore {
  MemoryPoolStore() : super(Future.value(Directory.systemTemp));

  final _pools = <String, Pool>{};

  @override
  Future<List<Pool>> loadAll() async => _pools.values.toList();

  @override
  Future<void> save(Pool pool) async => _pools[pool.id] = pool;

  @override
  Future<void> delete(String id) async => _pools.remove(id);
}

class MemoryCubeStore extends CubeStore {
  MemoryCubeStore() : super(Future.value(Directory.systemTemp));

  @override
  Future<List<Cube>> loadAll() async => [];
}

class MemoryCardInfoStore extends CardInfoStore {
  MemoryCardInfoStore() : super(Future.value(Directory.systemTemp));

  final _infos = <String, Map<String, CardInfo>>{};

  @override
  Future<Map<String, CardInfo>> load(String poolId) async => _infos[poolId] ?? {};

  @override
  Future<void> save(String poolId, Map<String, CardInfo> infos) async => _infos[poolId] = infos;

  @override
  Future<void> delete(String poolId) async => _infos.remove(poolId);
}
