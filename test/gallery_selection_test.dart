import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/features/card_text/domain/card_text.dart';
import 'package:opack/features/catalog/domain/models.dart';
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
}
