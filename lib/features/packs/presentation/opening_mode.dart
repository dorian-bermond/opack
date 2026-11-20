import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
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

/// The order the cards of a sealed deal are revealed in: pack after pack,
/// slot after slot (the first card of every pack, then the second…), or
/// the best cards first.
enum SealedOrder { byBooster, bySlot, byQuality }

extension SealedOrderLabel on SealedOrder {
  String label(AppLocalizations l10n) => switch (this) {
        SealedOrder.byBooster => l10n.sealedByBooster,
        SealedOrder.bySlot => l10n.sealedBySlot,
        SealedOrder.byQuality => l10n.sealedByQuality,
      };
}

/// The chosen [SealedOrder], saved across launches.
final sealedOrderProvider = NotifierProvider<SealedOrderSetting, SealedOrder>(SealedOrderSetting.new);

class SealedOrderSetting extends Notifier<SealedOrder> {
  static const _key = 'sealedOrder';

  @override
  SealedOrder build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    return SealedOrder.values.asNameMap()[saved] ?? SealedOrder.byBooster;
  }

  void select(SealedOrder order) {
    ref.read(sharedPreferencesProvider).setString(_key, order.name);
    state = order;
  }
}
