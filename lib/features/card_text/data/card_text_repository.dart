import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/card_text.dart';

/// All Yu-Gi-Oh! text versions, keyed by passcode. Loaded once, on first use.
final cardTextsProvider = FutureProvider<Map<String, CardTexts>>((ref) async {
  final json = await compute(
    _parse,
    await rootBundle.loadString('assets/cards/ygo_texts.json', cache: false),
  );
  return json;
});

Map<String, CardTexts> _parse(String text) => {
      for (final MapEntry(key: passcode, value: languages)
          in (jsonDecode(text) as Map<String, dynamic>).entries)
        passcode: {
          for (final MapEntry(key: lang, value: versions)
              in (languages as Map<String, dynamic>).entries)
            lang: [
              for (final v in versions as List) TextVersion.fromJson(v as Map<String, dynamic>),
            ],
        },
    };

/// Overridden in `main()` once preferences are loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not loaded'),
);

class TextPreferences {
  const TextPreferences({this.mode = TextVersionMode.printed, this.overrides = const {}});

  final TextVersionMode mode;

  /// User picks: `"<passcode>|<lang>"` -> version index.
  final Map<String, int> overrides;

  int? overrideFor(String passcode, String lang) => overrides['$passcode|$lang'];
}

final textPreferencesProvider =
    NotifierProvider<TextPreferencesController, TextPreferences>(TextPreferencesController.new);

class TextPreferencesController extends Notifier<TextPreferences> {
  static const _modeKey = 'textVersionMode';
  static const _overridesKey = 'textVersionOverrides';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  TextPreferences build() {
    final mode = TextVersionMode.values
            .where((m) => m.name == _prefs.getString(_modeKey))
            .firstOrNull ??
        TextVersionMode.printed;
    final raw = _prefs.getString(_overridesKey);
    final overrides = raw == null
        ? <String, int>{}
        : (jsonDecode(raw) as Map<String, dynamic>).cast<String, int>();
    return TextPreferences(mode: mode, overrides: overrides);
  }

  void setMode(TextVersionMode mode) {
    _prefs.setString(_modeKey, mode.name);
    state = TextPreferences(mode: mode, overrides: state.overrides);
  }

  /// Picks [index] for this card and language; `null` returns to the default.
  void choose(String passcode, String lang, int? index) {
    final overrides = {...state.overrides};
    if (index == null) {
      overrides.remove('$passcode|$lang');
    } else {
      overrides['$passcode|$lang'] = index;
    }
    _prefs.setString(_overridesKey, jsonEncode(overrides));
    state = TextPreferences(mode: state.mode, overrides: overrides);
  }
}
