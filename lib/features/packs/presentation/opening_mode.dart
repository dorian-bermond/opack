import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../card_text/data/card_text_repository.dart';

/// How a loose pack is revealed: every card face down in a grid, tapped one
/// by one; or a stack where swiping the top card away uncovers the next.
enum OpeningMode { grid, swipe }

/// The chosen [OpeningMode], saved across launches.
final openingModeProvider = NotifierProvider<OpeningModeSetting, OpeningMode>(OpeningModeSetting.new);

class OpeningModeSetting extends Notifier<OpeningMode> {
  static const _key = 'openingMode';

  @override
  OpeningMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    return OpeningMode.values.asNameMap()[saved] ?? OpeningMode.grid;
  }

  void select(OpeningMode mode) {
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
    state = mode;
  }
}
