import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/data/card_info_repository.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/features/pools/presentation/card_edit_sheet.dart';
import 'package:opack/features/pools/presentation/card_field_icons.dart';
import 'package:opack/l10n/app_localizations.dart';
import 'package:opack/shared/images/card_image_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show MemoryCardInfoStore;

void main() {
  testWidgets('a card with details opens in the editor, its subtypes picked by word', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const card = CardData(id: 'X-1', names: {'en': 'Mezuki'}, rarity: Rarity.common, passcode: '92826944');
    final pool = Pool.empty(Game.ygo, name: 'p', id: 'p').withSource(const CardsSource([card]), cards: [card]);
    final info = YgoCardInfo.fromYgoprodeck(const {
      'id': 92826944,
      'name': 'Mezuki',
      'type': 'Effect Monster',
      'frameType': 'effect',
      'race': 'Zombie',
      'attribute': 'EARTH',
      'level': 4,
      'atk': 1700,
      'def': 800,
      'desc': 'Text.',
    });
    final store = MemoryCardInfoStore();
    await store.save('p', {'X-1': info});
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      cardInfoStoreProvider.overrideWithValue(store),
      cardInfoFetcherProvider.overrideWithValue(null),
      cardImageCacheProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    // The sheet reads the details already loaded.
    await tester.runAsync(() => container.read(poolCardInfoProvider('p').future));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CardEditSheet(play: PlayPool.resolve(pool, sets: const {}, cubes: const {}), card: card),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The card is drawn beside its fields, as they make it.
    expect(find.byKey(const Key('editDrawnCard')), findsOneWidget);
    // It takes the height there is, the fields keeping their width.
    final drawnSize = tester.getSize(find.byKey(const Key('editDrawnCard')));
    expect(drawnSize.width, closeTo(1200 - 16 - 440, 1), reason: 'the fields keep 440 px');
    expect(drawnSize.height, greaterThan(1000));
    expect(find.descendant(of: find.byKey(const Key('editDrawnCard')), matching: find.text('1700')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('field-atk')), '2400');
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('editDrawnCard')), matching: find.text('2400')), findsOneWidget);

    // The fields come in the order the card shows them.
    double top(String key) => tester.getTopLeft(find.byKey(ValueKey('field-$key'))).dy;
    expect(top('card.name.en'), lessThan(top('attribute')));
    expect(top('attribute'), lessThan(top('level')));
    expect(top('level'), lessThan(top(ygoSubtypesKey)));
    expect(top(ygoSubtypesKey), lessThan(top('text')));
    expect(top('text'), lessThan(top('atk')));
    // ATK and DEF share a line, ATK first.
    expect(top('atk'), top('def'));
    expect(tester.getTopLeft(find.byKey(const ValueKey('field-atk'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('field-def'))).dx));
    // The rarities and "has effect" are not edited here.
    for (final key in ['card.rarity', 'card.printedRarity', 'hasEffect']) {
      expect(find.byKey(ValueKey('field-$key')), findsNothing, reason: key);
    }

    // The drawn card is edited by clicking it: the attribute in a dialog...
    await tester.tap(find.byKey(const ValueKey('ygoPart-attribute')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pickAttribute')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('attribute-FIRE')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('field-attribute'))).controller!.text, 'FIRE');
    // ...the level too...
    await tester.tap(find.byKey(const ValueKey('ygoPart-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('level-7')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('field-level'))).controller!.text, '7');
    expect(find.byKey(const ValueKey('ygoStar-6')), findsOneWidget, reason: 'seven stars drawn');
    // ...and the other parts send the focus to their field.
    await tester.tap(find.byKey(const ValueKey('ygoPart-text')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('field-text'))).focusNode!.hasFocus, isTrue);
    await tester.tap(find.byKey(const ValueKey('ygoPart-def')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('field-def'))).focusNode!.hasFocus, isTrue);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // The tribe is a field of its own, above the subtypes: a monster has one.
    final tribe = find.byKey(const ValueKey('field-race'));
    String? tribeNow() => tester.widget<DropdownButton<String>>(tribe).value;
    expect(find.text('Tribe'), findsOneWidget);
    expect(tribeNow(), 'Zombie');
    expect(top('level'), lessThan(top('race')));
    expect(top('race'), lessThan(top(ygoSubtypesKey)));

    // The subtypes hold the rest, in printed order (Tuner before Effect).
    List<String> chips() => [
          for (final chip in tester.widgetList<InputChip>(find.byType(InputChip))) (chip.label as Text).data!,
        ];
    final subtypes = find.byKey(const ValueKey('field-$ygoSubtypesKey'));
    Future<void> pick(String typed, String option) async {
      await tester.ensureVisible(subtypes);
      await tester.enterText(subtypes, typed);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, option));
      await tester.pumpAndSettle();
    }

    expect(chips(), ['Effect']);
    await pick('Tun', 'Tuner');
    await pick('Synch', 'Synchro');
    expect(chips(), ['Synchro', 'Tuner', 'Effect'], reason: 'the frame, then Tuner, then Effect');
    // No tribe is offered among the subtypes.
    await tester.enterText(subtypes, 'Drag');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Dragon'), findsNothing);
    await tester.enterText(subtypes, '');
    await tester.pumpAndSettle();
    // The type line they make with the tribe reads just under them.
    expect(tester.widget<Text>(find.byKey(const Key('typeLine'))).data, 'Zombie / Synchro / Tuner / Effect');
    final line = tester.getTopLeft(find.byKey(const Key('typeLine'))).dy;
    expect(line, greaterThan(tester.getTopLeft(subtypes).dy));
    expect(line, lessThan(tester.getTopLeft(find.byKey(const ValueKey('field-text'))).dy));

    // The tribe is changed in its field, a plain list of every tribe of the game...
    await tester.ensureVisible(tribe);
    await tester.tap(tribe);
    await tester.pumpAndSettle();
    expect(find.text('Winged Beast'), findsWidgets, reason: 'every tribe, also one no card of the pool has');
    await tester.tap(find.text('Dragon').last);
    await tester.pumpAndSettle();
    expect(tribeNow(), 'Dragon');
    expect(chips(), ['Synchro', 'Tuner', 'Effect'], reason: 'the subtypes stay');
    expect(tester.widget<Text>(find.byKey(const Key('typeLine'))).data, 'Dragon / Synchro / Tuner / Effect');
    expect(find.descendant(of: find.byKey(const Key('editDrawnCard')), matching: find.textContaining('Dragon')),
        findsOneWidget, reason: 'the drawn type line follows');
    // ...or by a click on the drawn card's type line, in a dialog.
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ygoPart-type')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pickTribe')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tribe-Zombie')));
    await tester.pumpAndSettle();
    expect(tribeNow(), 'Zombie');

    Future<void> remove(String word) async {
      tester.widget<InputChip>(find.byKey(ValueKey('pick-$ygoSubtypesKey-$word'))).onDeleted!();
      await tester.pumpAndSettle();
    }

    await remove('Synchro');
    await remove('Tuner');
    expect(chips(), ['Effect']);
    // A word taken out can be put back at once, as often as wanted.
    await pick('Tun', 'Tuner');
    expect(chips(), ['Tuner', 'Effect']);
    await remove('Tuner');
    await pick('Tun', 'Tuner');
    await remove('Tuner');
    await remove('Effect');
    await pick('Eff', 'Effect');
    expect(chips(), ['Effect']);
    // Without typing either: the open list offers the word again once removed.
    await tester.tap(subtypes);
    await tester.pumpAndSettle();
    // (Fusion is near the head of the list, in view without scrolling.)
    await tester.tap(find.widgetWithText(ListTile, 'Fusion'));
    await tester.pumpAndSettle();
    expect(chips(), ['Fusion', 'Effect']);
    expect(find.widgetWithText(ListTile, 'Fusion'), findsNothing, reason: 'picked: no longer offered');
    await remove('Fusion');
    expect(find.widgetWithText(ListTile, 'Fusion'), findsOneWidget, reason: 'offered again at once');
    await tester.tap(find.widgetWithText(ListTile, 'Fusion'));
    await tester.pumpAndSettle();
    expect(chips(), ['Fusion', 'Effect']);
    await remove('Fusion');
    expect(chips(), ['Effect']);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // On a short window the drawn card shrinks instead of overflowing.
    tester.view.physicalSize = const Size(1200, 520);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final short = tester.getSize(find.byKey(const Key('editDrawnCard')));
    expect(short.height, lessThan(520));
    expect(short.height, greaterThan(400), reason: 'as tall as the window lets it');
    tester.view.physicalSize = const Size(1200, 2400);
    await tester.pumpAndSettle();

    // The subtypes: each a chip, one more picked among the known words.
    final field = find.byKey(const ValueKey('field-$ygoSubtypesKey'));
    expect(field, findsOneWidget);
    expect(find.byKey(const ValueKey('pick-$ygoSubtypesKey-Effect')), findsOneWidget);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Tun');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Tuner'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pick-$ygoSubtypesKey-Tuner')), findsOneWidget);

    // Fields and values carry their icons: the attribute its own, in color.
    // (the attribute was changed to FIRE on the card above)
    AssetImage picture(Finder finder) => tester.widget<Image>(finder).image as AssetImage;
    expect(picture(find.byKey(const ValueKey('valueIcon-attribute'))).assetName,
        'assets/ygo_template/attribute-fire.png', reason: "the template's own attribute");
    expect(
      picture(find.descendant(
        of: find.byKey(const ValueKey('valueIcon-race-Zombie')),
        matching: find.byType(Image),
      ).first).assetName,
      'assets/ygo_types/zombie.png',
      reason: "the tribe's own icon",
    );
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget, reason: 'the DEF field');
    expect(find.byIcon(Icons.tune), findsOneWidget, reason: 'the Tuner chip');
    expect(tester.widget<TextField>(field).controller!.text, isEmpty, reason: 'free for the next word');

    // Known values have an icon, whatever their case; a word of one's own none.
    expect(valueIcon(Game.ygo, 'attribute', 'FIRE')!.icon, Icons.local_fire_department);
    expect(valueIcon(Game.ygo, 'subtypes', 'Zombie'), isNotNull);
    expect(valueIcon(Game.ygo, 'subtypes', 'My own type'), isNull);
    expect(valueIcon(Game.mtg, 'types', 'Creature')!.icon, Icons.pets);
    expect(valueIcon(Game.opc, 'attribute', 'Slash'), isNotNull);
    expect(valueImage(Game.ygo, 'subtypes', 'Beast-Warrior'), 'assets/ygo_types/beastwarrior.png');
    expect(valueImage(Game.ygo, 'subtypes', 'Sea Serpent'), 'assets/ygo_types/seaserpent.png');
    expect(valueImage(Game.ygo, 'subtypes', 'Quick-Play'), 'assets/ygo_template/icon-quick-play.png');
    expect(valueImage(Game.ygo, 'subtypes', 'Tuner'), isNull, reason: 'no picture: the pictogram');
    expect(valueImage(Game.opc, 'attribute', 'Slash'), isNull);
    expect(fieldIcon('card.name.fr'), Icons.badge_outlined);
    expect(fieldIcon('passcode'), isNull);
  });
}
