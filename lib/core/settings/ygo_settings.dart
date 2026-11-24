import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/card_info/domain/card_info.dart';
import '../../features/card_text/data/card_text_repository.dart';

/// Whether Yu-Gi-Oh! monsters are told apart as normal and effect monsters
/// wherever cards are sorted, grouped or filtered by kind; saved across
/// launches, on by default. Mirrored into [YgoKinds] for the pure code.
final ygoSplitNormalEffectProvider =
    NotifierProvider<YgoSplitNormalEffectSetting, bool>(YgoSplitNormalEffectSetting.new);

class YgoSplitNormalEffectSetting extends Notifier<bool> {
  static const _key = 'ygoSplitNormalEffect';

  @override
  bool build() {
    final on = ref.read(sharedPreferencesProvider).getBool(_key) ?? true;
    YgoKinds.splitNormalEffect = on;
    return on;
  }

  void set(bool on) {
    ref.read(sharedPreferencesProvider).setBool(_key, on);
    YgoKinds.splitNormalEffect = on;
    state = on;
  }
}
