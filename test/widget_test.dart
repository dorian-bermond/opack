import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/app.dart';
import 'package:opack/core/router.dart';
import 'package:opack/core/settings/locale_controller.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/features/card_info/data/card_info_repository.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_info/presentation/card_search_sheet.dart';
import 'package:opack/features/catalog/data/catalog_repository.dart';
import 'package:opack/features/cube/data/cube_repository.dart';
import 'package:opack/features/cube/domain/cube.dart';
import 'package:opack/features/pools/data/pool_repository.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/shared/images/artwork_search.dart';
import 'package:opack/shared/images/card_image_cache.dart';
import 'package:opack/shared/widgets/card_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the app on the real bundled catalog, in [locale] or else the
/// device language.
Future<ProviderContainer> startApp(WidgetTester tester, {Locale? locale}) async {
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
      cardSearchProvider.overrideWithValue(null),
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
    expect(find.text('Cards from'), findsOneWidget);
    expect(find.text('Unlimited packs'), findsOneWidget);

    await tester.tap(find.text('Closed'));
    await tester.pumpAndSettle();
    expect(find.text('1 × each card'), findsOneWidget);
    expect(find.textContaining('of 9 cards available'), findsOneWidget);

    // Every view shows the same cards; the stacks group them by rarity.
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(CardTile), findsWidgets);
    expect(find.textContaining('×'), findsWidgets);
    await tester.tap(find.text('Stacks'));
    await tester.pumpAndSettle();
    // The stacks column header, next to the layout tag chip of the same name.
    expect(find.textContaining('Secret rare · '), findsNWidgets(2));
    await tester.tap(find.text('Spoiler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CIBR-FR0'), findsWidgets);
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    // Tag a card in bulk, pull one such card per pack, then drop the slot.
    expect(find.textContaining('7 × Common'), findsOneWidget);
    await tester.tap(find.text('New tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'mine');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Tagging: mine'), findsOneWidget);
    // Tap a card row that is on screen (the last built one may lie below).
    await tester.tap(find.ancestor(of: find.textContaining('CIBR-FR0'), matching: find.byType(ListTile)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('mine · 1'), findsOneWidget);
    // Group the list by tag: the tagged card sits under its own header.
    await tester.tap(find.byTooltip('Group by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tag').last);
    await tester.pumpAndSettle();
    expect(find.text('mine · 1'), findsNWidgets(2), reason: 'the chip and the group header');
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
    expect(find.textContaining('Common · '), findsWidgets, reason: 'rarity sections inside tag groups');
    await tester.tap(find.byTooltip('Group by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No grouping'));
    await tester.pumpAndSettle();

    // A layout tag is editable too: drop one card from the commons.
    final commonChip =
        find.descendant(of: find.byType(InputChip), matching: find.textContaining(RegExp(r'^Common · ')));
    expect(commonChip, findsOneWidget);
    await tester.tap(commonChip);
    await tester.pumpAndSettle();
    expect(find.text('Tagging: common'), findsOneWidget);
    await tester.tap(find.ancestor(of: find.textContaining('CIBR-FR0'), matching: find.byType(ListTile)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^Common · ')), findsOneWidget);

    // Deleting a tag warns about the slots pulling from it.
    final commonChipWidget = find.ancestor(of: commonChip, matching: find.byType(InputChip));
    await tester.tap(find.descendant(of: commonChipWidget, matching: find.byTooltip('Delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete the tag Common?'), findsOneWidget);
    expect(find.textContaining('7 × Common'), findsNWidgets(2), reason: 'summary and warning');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(commonChip, findsOneWidget);

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
    expect(find.text('Cards from'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Circuit Break'), findsOneWidget);
    expect(find.text('Closed ×1'), findsOneWidget);

    await tester.tap(find.text('Sealed'));
    await settleLoading(tester);
    expect(find.text('Sealed pool'), findsOneWidget);
    expect(find.textContaining('Closed ×1 · 5 packs · 45 cards'), findsOneWidget);
  });

  testWidgets('an empty pool cannot be played until it has a source', (tester) async {
    await startApp(tester, locale: const Locale('en'));

    await tester.tap(find.text('New pool'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yu-Gi-Oh!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty pool'));
    await settleLoading(tester);
    expect(find.text('Cards from'), findsOneWidget);
    expect(find.text('Add a set or cube'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('No cards yet'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Open a pack').first).enabled,
      isFalse,
    );

    await tester.tap(find.text('Edit'));
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
