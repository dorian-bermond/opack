import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/card_text/data/card_text_repository.dart';

/// Selected UI language, saved across launches; `null` follows the system.
final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'locale';

  @override
  Locale? build() {
    final code = ref.read(sharedPreferencesProvider).getString(_key);
    return code == null ? null : Locale(code);
  }

  void select(Locale? locale) {
    final prefs = ref.read(sharedPreferencesProvider);
    locale == null ? prefs.remove(_key) : prefs.setString(_key, locale.languageCode);
    state = locale;
  }
}
