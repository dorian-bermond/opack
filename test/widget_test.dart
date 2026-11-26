import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/core/settings/ygo_settings.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/core/update/app_update.dart';
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
      updateCheckerProvider.overrideWithValue(null),
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
/// Picks [label] in the View dialog's group-by (or then-by) dropdown, and
/// closes the dialog unless told otherwise (a question may follow).
Future<void> setGroupBy(WidgetTester tester, String label, {bool thenBy = false, bool close = true}) async {
  // The View chip sits in the header, which a long list may have scrolled away.
  if (find.byType(CustomScrollView).evaluate().isNotEmpty) {
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('viewChip')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(thenBy ? 'thenBy' : 'groupBy')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
  if (close) await closeView(tester);
}

Future<void> closeView(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('viewClose')));
  await tester.pumpAndSettle();
}

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
    final container = await startApp(tester, locale: const Locale('en'));
    expect(find.text('Opack'), findsOneWidget);
    await createPoolFromSet(tester, 'circuit', newPool: 'New pool', fromSet: 'From a set');
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Cards from'), findsNothing, reason: 'sources live on the details page');

    // Copies are set in a mode of their own, like the tierlist.
    await tester.tap(find.byKey(const Key('copiesButton')));
    await settleLoading(tester);
    expect(find.text('Copies'), findsOneWidget);
    expect(find.byType(CardTile), findsWidgets);
    expect(find.textContaining('×'), findsWidgets, reason: 'every card badged with its copies here');
    await tester.pageBack();
    await tester.pumpAndSettle();

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
    expect(find.textContaining('×'), findsNothing, reason: 'no ×1 badge on untouched cards by default');
    container.read(copiesBadgeProvider.notifier).select(CopiesBadgeMode.always);
    await tester.pumpAndSettle();
    expect(find.textContaining('×'), findsWidgets, reason: 'every card badged on demand');
    container.read(copiesBadgeProvider.notifier).select(CopiesBadgeMode.changed);
    await tester.pumpAndSettle();
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
    await setGroupBy(tester, 'Tag');
    // Groups follow the pool's tag order: the big common group comes first.
    await tester.scrollUntilVisible(find.text('mine · 1'), 400,
        scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('mine · 1'), findsOneWidget, reason: 'the group header');
    // Back to the top: the count line sits in the scrolled-away header.
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    // Ctrl+A selects every card shown, Escape clears; Ctrl+F reaches the search bar.
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.textContaining('100 selected'), findsOneWidget, reason: 'every card shown');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.textContaining('selected'), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(tester.binding.focusManager.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>(), isNotNull,
        reason: 'the search bar took the focus');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // A card's fields are edited for the pool: the name changes, flagged custom.
    await tester.longPress(find.descendant(of: find.byType(PoolListSliver), matching: find.byType(ListTile)).first);
    await settleLoading(tester);
    await tester.tap(find.byKey(const Key('editCard')));
    await settleLoading(tester);
    expect(find.byKey(const ValueKey('custom-card.name.en')), findsNothing, reason: 'nothing custom yet');
    expect(find.byKey(const ValueKey('field-card.colors')), findsNothing, reason: 'no color letters on a Yu-Gi-Oh! card');
    await tester.enterText(find.byKey(const ValueKey('field-card.name.en')), 'Renamed card');
    await settleLoading(tester);
    expect(find.byKey(const ValueKey('custom-card.name.en')), findsOneWidget);
    expect(find.byKey(const ValueKey('revert-card.name.en')), findsOneWidget, reason: 'the original comes back on demand');
    await tester.tap(find.byKey(const Key('applyCardEdit')));
    await settleLoading(tester);
    expect(find.text('Renamed card'), findsWidgets, reason: 'the pool shows the custom name');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // The pencil on a row opens that editor directly.
    await tester.tap(
        find.descendant(of: find.byType(PoolListSliver), matching: find.byIcon(Icons.edit_outlined)).first);
    await settleLoading(tester);
    expect(find.byKey(const Key('applyCardEdit')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('applyCardEdit')))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('applyCardEdit')), findsNothing);

    // A right-click on the header selects the group and opens its operations.
    await tester.scrollUntilVisible(find.text('mine · 1'), 400,
        scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('mine · 1')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selectionTags')), findsOneWidget, reason: 'the selection menu');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selectionTags')), findsNothing);
    // Headers fold their section.
    expect(find.byIcon(Icons.expand_more), findsNothing);
    await tester.tap(find.text('mine · 1').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_more), findsOneWidget, reason: 'the mine group is folded');
    await tester.tap(find.text('mine · 1').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_more), findsNothing);
    // A secondary grouping nests rarity sections under each tag.
    await setGroupBy(tester, 'Rarity', thenBy: true);
    await tester.scrollUntilVisible(find.text('mine · 1'), 400,
        scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('Secret rare · 1'), findsWidgets, reason: 'the rarity section inside the mine group');
    await setGroupBy(tester, 'No grouping');

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
    expect(find.textContaining('7 × Common'), findsOneWidget, reason: 'the warning');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(commonChip, findsOneWidget);

    // The composition sits on the booster tab of the details page.
    await tester.tap(find.byKey(const Key('boosterTab')));
    await tester.pumpAndSettle();
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
    expect(find.byKey(const Key('chooseCover')), findsOneWidget, reason: 'the pack picture lives here too');
    // The transfer tab offers export and import.
    await tester.tap(find.byKey(const Key('transferTab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exportPool')), findsOneWidget);
    expect(find.byKey(const Key('importPool')), findsOneWidget);
    expect(find.byTooltip('Rename'), findsNothing, reason: 'the name itself renames');

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
        final fname = request.url.queryParameters['fname']!.toLowerCase();
        // "mock" finds the dragon (and a decoy first); anything else nothing.
        if (!fname.contains('mock')) return http.Response('', 400);
        return http.Response(jsonEncode({
          'data': [
            if (fname == 'mock dragon')
              {
                'id': 11111111,
                'name': 'Mock Dragon Lord',
                'type': 'Effect Monster',
                'frameType': 'effect',
                'race': 'Dragon',
                'attribute': 'DARK',
                'level': 10,
                'atk': 4000,
                'def': 3000,
                'desc': 'A decoy sharing the name.',
                'card_sets': [
                  {'set_code': 'MOCK-EN002', 'set_rarity': 'Rare'},
                ],
              },
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
    final container = await startApp(tester, locale: const Locale('en'), cardSearch: search);
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

    // In gallery mode each side has its own cards-per-row setting: the
    // panel's in its toolbar, the pool's in the size dialog.
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('auto'), findsOneWidget, reason: "the panel's; the pool's sits in a dialog");
    await tester.tap(find.byKey(const ValueKey('moreColumns-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moreColumns-search')));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sizeOptions')));
    await tester.pumpAndSettle();
    expect(find.text('auto'), findsOneWidget, reason: "the pool's");
    await tester.tap(find.byKey(const ValueKey('moreColumns-pool')));
    await tester.pumpAndSettle();
    expect(find.text('auto'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'the panel keeps its own');
    await tester.tap(find.byKey(const ValueKey('fewerColumns-pool')));
    await tester.pumpAndSettle();
    expect(find.text('auto'), findsOneWidget);

    // The pool gallery has size and spacing sliders as the tierlist: the
    // spacing may go negative, overlapping the cards.
    expect(find.byKey(const ValueKey('gallerySize-pool')), findsOneWidget);
    expect(tester.widget<Slider>(find.byKey(const ValueKey('gallerySize-pool'))).onChanged, isNotNull,
        reason: 'auto per row: the size slider sets the width');
    container.read(galleryColumnsProvider('pool').notifier).set(2);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byKey(const ValueKey('gallerySize-pool'))).onChanged, isNull,
        reason: 'a fixed number per row sets the size itself');
    expect(find.byKey(const ValueKey('gallerySpacing-pool')), findsOneWidget);
    container.read(galleryColumnsProvider('pool').notifier).set(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sizeClose')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    // The splitter widens the panel when dragged left.
    double panelWidth() => tester.getSize(find.byType(SearchPanel)).width;
    final before = panelWidth();
    await tester.drag(find.byKey(const Key('panelSplitter')), const Offset(-120, 0));
    await tester.pumpAndSettle();
    // Touch slop eats the first few pixels of the drag.
    expect(panelWidth(), inInclusiveRange(before + 90, before + 120));

    // A batch import: each line looked up, exact name first, then tagged.
    await tester.tap(find.byKey(const Key('batchImport')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('batchList')), '1 Mock Dragon\n\nNope Card\n2x Mock Dragon');
    await tester.tap(find.byKey(const Key('batchLookUp')));
    await tester.pumpAndSettle();
    expect(find.text('1 card found · 1 line unmatched'), findsOneWidget, reason: 'the decoy loses, duplicates merge');
    expect(find.text('Nope Card'), findsOneWidget);
    // Looked up: the options tab opened, the list one still a tap away.
    expect(find.byKey(const Key('batchList')), findsNothing);
    expect(find.byKey(const Key('batchRarities')), findsOneWidget);
    await tester.tap(find.byKey(const Key('batchTabList')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('batchList')), findsOneWidget);
    await tester.tap(find.byKey(const Key('batchNext')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('batchNewTag')), 'imported');
    await tester.tap(find.byKey(const Key('batchAddTag')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('batchTag-imported')), findsOneWidget);
    await tester.tap(find.byKey(const Key('batchApply')));
    await settleLoading(tester);
    final imported = container.read(poolsProvider).value!.single;
    expect(imported.tags['imported']!.cards, ['MOCK-EN001']);
    expect(imported.sources.whereType<CardsSource>().single.cards.map((c) => c.id), ['MOCK-EN001']);
    expect(find.text('Mock Dragon'), findsNWidgets(2), reason: 'in the pool and in the results');

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
    // Cards of a tier by rank: left to right, top to bottom on screen (the
    // tree paints them in another order so the left card is on top).
    List<(String, Rect)> rankedCards() {
      final cards = find.descendant(of: rare, matching: find.byType(DraggableCard));
      final list = [
        for (var i = 0; i < cards.evaluate().length; i++)
          (tester.widget<DraggableCard>(cards.at(i)).card.id, tester.getRect(cards.at(i))),
      ];
      list.sort((a, b) => a.$2.top != b.$2.top ? a.$2.top.compareTo(b.$2.top) : a.$2.left.compareTo(b.$2.left));
      return list;
    }

    final firstId = rankedCards()[0].$1;
    final thirdId = rankedCards()[2].$1;
    final first = find.byKey(ValueKey('ranked-$firstId'));
    final third = find.byKey(ValueKey('ranked-$thirdId'));
    await tester.timedDrag(third, tester.getCenter(first) - tester.getCenter(third), const Duration(milliseconds: 400));
    await settleLoading(tester);
    expect(rankedCards().take(2).map((c) => c.$1), [thirdId, firstId]);
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
    // The last quality used is remembered on the pool for the next time.
    expect(container.read(poolsProvider).value!.single.tierlistQuality, 'power');
    await tester.pageBack();
    await settleLoading(tester);
    await tester.tap(find.byKey(const Key('tierlistButton')));
    await settleLoading(tester);
    expect(find.text('Quality: Power'), findsOneWidget, reason: 'reopened on Power');
    await tester.tap(find.byKey(const Key('tierlistQuality')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rarity'));
    await tester.pumpAndSettle();
    expect(container.read(poolsProvider).value!.single.tierlistQuality, 'rarity');

    // The size slider scales every card of the tiers and the feed.
    double cardWidth() => tester.getSize(find.descendant(of: rare, matching: find.byType(DraggableCard)).first).width;
    expect(cardWidth(), 96);
    expect(tester.widget<Slider>(find.byKey(const Key('tierlistCardSize'))).value, 96);
    container.read(tierlistCardWidthProvider.notifier).set(120);
    await tester.pumpAndSettle();
    expect(cardWidth(), 120);
    expect(tester.widget<Slider>(find.byKey(const Key('tierlistCardSize'))).value, 120);

    // Spacing: 8 px apart by default; negative, the cards overlap with the
    // left one on top and the lower row on top.
    Rect rankedRect(int i) => rankedCards()[i].$2;
    expect(rankedRect(1).left - rankedRect(0).right, 8);
    container.read(tierlistSpacingProvider.notifier).set(-40);
    await tester.pumpAndSettle();
    expect(rankedRect(1).left, rankedRect(0).left + 120 - 40);
    expect(rankedRect(0).top, rankedRect(1).top);
    final columns = ((tester.getSize(rare).width - 96 - 16 - 120) / 80).floor() + 1;
    expect(rankedRect(columns).top, closeTo(rankedRect(0).top + 120 * 86 / 59 - 40, 0.5), reason: 'rows overlap too, a Yu-Gi-Oh! card tall');
    expect(rankedRect(columns).left, rankedRect(0).left);
    container.read(tierlistSpacingProvider.notifier).set(8);
    await tester.pumpAndSettle();

    // Editing the quality as a whole: rename, recolor, reorder, delete values.
    await tester.tap(find.byKey(const Key('tierlistEditQuality')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Edit the quality'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('qualityValue-0'))).controller!.text, 'secretRare',
        reason: 'values listed best first');
    await tester.enterText(find.byKey(const ValueKey('qualityValue-0')), 'secret');
    await tester.tap(find.byKey(const ValueKey('qualityValueCopies-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('×3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qualityValueDelete-1')), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qualityValueDown-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await settleLoading(tester);
    final tags = container.read(poolsProvider).value!.single;
    expect(tags.tags.containsKey('rarity:ultraRare'), isFalse, reason: 'deleted');
    expect(tags.tags.containsKey('rarity:secretRare'), isFalse, reason: 'renamed');
    expect(tags.tags['rarity:secret']!.cards.length, 8, reason: 'kept its cards');
    expect(tags.tags['rarity:secret']!.copies, 3, reason: 'copies set on the value');
    expect(tags.copiesOf('CIBR-FR042'), 3, reason: 'a secret rare card has 3 copies now');
    expect(tags.orderedValuesOf('rarity').take(2), ['rarity:superRare', 'rarity:secret'], reason: 'moved down one');
    expect(find.byKey(const ValueKey('tier-rarity:secret')), findsOneWidget);
    expect(find.byKey(const ValueKey('tier-rarity:ultraRare')), findsNothing);
    await tester.tap(find.byKey(const Key('tierlistUndo')), warnIfMissed: false);
    await settleLoading(tester);

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

    // The feed has a scrollbar, and the mouse wheel scrolls it sideways.
    final strip = find.byKey(const Key('feedStrip'));
    expect(find.descendant(of: strip, matching: find.byType(Scrollbar)), findsOneWidget);
    final firstFeedCard = find.descendant(of: strip, matching: find.byType(CardTile)).first;
    final leftBefore = tester.getTopLeft(firstFeedCard).dx;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(strip));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 150)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(firstFeedCard).dx, leftBefore - 150, reason: 'a vertical wheel turn moves the strip');
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -500)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(firstFeedCard).dx, leftBefore, reason: 'clamped at the start');

    // Back in the editor, grouping by quality asks which one now that
    // the pool has two.
    await tester.pageBack();
    await settleLoading(tester);
    await setGroupBy(tester, 'Quality', close: false);
    expect(find.text('Group by which quality?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('groupQuality-power')));
    await tester.pumpAndSettle();
    await closeView(tester);
    expect(find.textContaining('ø · '), findsOneWidget, reason: 'nothing holds a Power value');
    expect(find.textContaining('Rarity: '), findsNothing, reason: 'rarity left out');
    // Stacks grouped twice: one row of stacks per primary group.
    await setGroupBy(tester, 'Rarity', thenBy: true);
    await tester.tap(find.text('Stacks'));
    await tester.pumpAndSettle();
    expect(find.byType(PoolStacksSliver), findsOneWidget, reason: 'one primary group, one row');
    expect(find.textContaining('Secret rare · '), findsOneWidget, reason: 'a stack per rarity inside it');
    expect(find.textContaining('ø · '), findsOneWidget);
    expect(find.byKey(const ValueKey('stack-common-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('stack-common-8')), findsOneWidget, reason: 'a tall column is cut into stacks');
    expect(find.byKey(const ValueKey('stackGroup-common')), findsOneWidget, reason: 'all in one panel');
    expect(find.descendant(of: find.byKey(const ValueKey('stackGroup-common')), matching: find.textContaining('Common · ')), findsOneWidget, reason: 'one header');
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    await setGroupBy(tester, 'No grouping');
    await tester.tap(find.byKey(const Key('tierlistButton')));
    await settleLoading(tester);

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

  testWidgets('slashing across the pack tears it open; a short slash does not', (tester) async {
    await startApp(tester, locale: const Locale('en'));
    await createPoolFromSet(tester, 'circuit', newPool: 'New pool', fromSet: 'From a set');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open a pack'));
    await settleLoading(tester);
    final pack = find.byKey(const Key('sealedPack'));
    expect(pack, findsOneWidget);
    final width = tester.getSize(pack).width;
    expect(width, greaterThan(120), reason: 'sized to the window');

    // Too short a slash: still sealed.
    await tester.timedDrag(pack, Offset(width * 0.3, 0), const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sealedPack')), findsOneWidget);
    expect(find.byType(CardTile), findsNothing);

    // A slash across most of it tears the pack, and the cards come out;
    // it may start beside the pack, on the screen.
    final start = tester.getTopLeft(pack) + Offset(-60, tester.getSize(pack).height * 0.3);
    await tester.timedDragFrom(start, Offset(width * 0.8 + 60, 0), const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sealedPack')), findsNothing);
    expect(find.byType(CardTile), findsWidgets);
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

  testWidgets('settings live on their own page, rarity colors included', (tester) async {
    final container = await startApp(tester, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('setting-language')), findsOneWidget, reason: 'languages on the General tab');
    await tester.tap(find.byKey(const Key('settingsCards')));
    await tester.pumpAndSettle();
    expect(find.text('Rarity colors'), findsOneWidget);

    // The hover preview is turned off among its sizes.
    expect(container.read(cardHoverPreviewSizeProvider), HoverPreviewSize.normal);
    await tester.tap(find.byKey(const ValueKey('setting-Card hover preview-HoverPreviewSize.none')));
    await tester.pumpAndSettle();
    expect(container.read(cardHoverPreviewSizeProvider), HoverPreviewSize.none);
    expect(container.read(copiesBadgeProvider), CopiesBadgeMode.changed, reason: 'no ×1 badge by default');

    // The Yu-Gi-Oh! tab: normal and effect monsters told apart, on by default.
    await tester.tap(find.byKey(const Key('settingsYgo')));
    await tester.pumpAndSettle();
    expect(container.read(ygoSplitNormalEffectProvider), isTrue);
    await tester.tap(find.byKey(const Key('settingYgoNormalEffect')));
    await tester.pumpAndSettle();
    expect(container.read(ygoSplitNormalEffectProvider), isFalse);
    expect(YgoKinds.splitNormalEffect, isFalse);
    await tester.tap(find.byKey(const Key('settingYgoNormalEffect')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsCards')));
    await tester.pumpAndSettle();

    // A rarity color is picked from the palette, then reset.
    final before = Rarity.rare.color;
    // The tab view scrolls too: the list inside it is the one to scroll.
    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rarityColor-rare')), 300, scrollable: list);
    await tester.tap(find.byKey(const ValueKey('rarityColor-rare')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('swatch-${const Color(0xFF1E88E5).toARGB32()}')));
    await tester.pumpAndSettle();
    expect(Rarity.rare.color, const Color(0xFF1E88E5));
    expect(container.read(rarityColorsProvider)[Rarity.rare], const Color(0xFF1E88E5));
    await tester.tap(find.byKey(const ValueKey('rarityColorReset-rare')));
    await tester.pumpAndSettle();
    expect(Rarity.rare.color, before);
    expect(find.byKey(const ValueKey('rarityColorReset-rare')), findsNothing);
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
