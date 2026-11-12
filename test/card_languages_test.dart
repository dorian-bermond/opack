import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/core/settings/card_languages.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('picture and data languages are chosen apart and saved', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(cardLanguagesProvider).picture, isNull);
    expect(container.read(cardLanguagesProvider).data, isNull);

    container.read(cardLanguagesProvider.notifier).selectPicture('en');
    container.read(cardLanguagesProvider.notifier).selectData('fr');
    expect(container.read(cardLanguagesProvider).picture, 'en');
    expect(container.read(cardLanguagesProvider).data, 'fr');
    expect(prefs.getString('pictureLanguage'), 'en');
    expect(prefs.getString('dataLanguage'), 'fr');

    container.read(cardLanguagesProvider.notifier).selectPicture(null);
    expect(container.read(cardLanguagesProvider).picture, isNull);
    expect(container.read(cardLanguagesProvider).data, 'fr', reason: 'untouched');
    expect(prefs.containsKey('pictureLanguage'), isFalse);

    // A fresh container reads the saved choices back.
    final again = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(again.dispose);
    expect(again.read(cardLanguagesProvider).data, 'fr');
  });
}
