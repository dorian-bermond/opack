import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/card_text/data/card_text_repository.dart';

/// Languages chosen for cards, apart from the UI language: the language of
/// their pictures and the language of their names and texts. `null` follows
/// the UI language.
class CardLanguages {
  const CardLanguages({this.picture, this.data});

  final String? picture;
  final String? data;

  CardLanguages copyWith({String? Function()? picture, String? Function()? data}) => CardLanguages(
        picture: picture == null ? this.picture : picture(),
        data: data == null ? this.data : data(),
      );
}

final cardLanguagesProvider =
    NotifierProvider<CardLanguagesSetting, CardLanguages>(CardLanguagesSetting.new);

class CardLanguagesSetting extends Notifier<CardLanguages> {
  static const _pictureKey = 'pictureLanguage';
  static const _dataKey = 'dataLanguage';

  @override
  CardLanguages build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return CardLanguages(picture: prefs.getString(_pictureKey), data: prefs.getString(_dataKey));
  }

  void selectPicture(String? code) {
    _store(_pictureKey, code);
    state = state.copyWith(picture: () => code);
  }

  void selectData(String? code) {
    _store(_dataKey, code);
    state = state.copyWith(data: () => code);
  }

  void _store(String key, String? code) {
    final prefs = ref.read(sharedPreferencesProvider);
    code == null ? prefs.remove(key) : prefs.setString(key, code);
  }
}

/// The language card pictures are fetched in.
String pictureLanguage(WidgetRef ref, BuildContext context) =>
    ref.watch(cardLanguagesProvider).picture ?? Localizations.localeOf(context).languageCode;

/// The language card names and texts are shown in.
String dataLanguage(WidgetRef ref, BuildContext context) =>
    ref.watch(cardLanguagesProvider).data ?? Localizations.localeOf(context).languageCode;
