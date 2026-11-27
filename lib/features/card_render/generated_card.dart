import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../shared/images/card_image_cache.dart';
import '../card_info/data/card_info_repository.dart';
import '../card_info/domain/card_info.dart';
import '../card_text/data/card_text_repository.dart';
import '../card_text/presentation/card_details_sheet.dart';
import '../catalog/domain/models.dart';
import '../pools/domain/play_pool.dart';
import 'ygo_card_face.dart';

/// Whether a card whose fields were edited for a pool is drawn from its
/// details instead of shown as its scan, which no longer tells the truth;
/// saved across launches, on by default.
final generatedCardsProvider = NotifierProvider<GeneratedCardsSetting, bool>(GeneratedCardsSetting.new);

class GeneratedCardsSetting extends Notifier<bool> {
  static const _key = 'generatedCards';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool enabled) {
    ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    state = enabled;
  }
}

/// The details [card] is drawn from in [play], when it is to be drawn
/// rather than shown as its scan: a Yu-Gi-Oh! card of the pool with edited
/// fields, whose details are known. `null` otherwise.
YgoCardInfo? generatedYgoInfo(WidgetRef ref, PlayPool? play, CardData card) {
  if (play == null || play.pool.game != Game.ygo || card.customFields.isEmpty) return null;
  if (!ref.watch(generatedCardsProvider)) return null;
  final infos = ref.watch(poolCardInfoProvider(play.pool.id)).value?.infos;
  final info = play.customizedInfo(card.id, infos?[card.id]);
  return info is YgoCardInfo ? info : null;
}

/// [card] drawn from [info] (see [YgoCardFace]) in the data language, with
/// its artwork once downloaded.
class GeneratedYgoCard extends ConsumerWidget {
  const GeneratedYgoCard({super.key, required this.card, required this.info, this.name, this.code, this.onPart});

  final CardData card;
  final YgoCardInfo info;

  /// The name printed, when not the card's shown one (a name being typed).
  final String? name;

  /// The print code printed, when not the card's own (one being typed).
  final String? code;

  /// Makes the card's parts clickable (see [YgoCardFace.onPart]).
  final void Function(YgoCardPart part)? onPart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = dataLanguage(ref, context);
    final source = ygoArtworkSource(card);
    final artwork = source == null ? null : ref.watch(cardImageProvider(source)).value;
    return YgoCardFace(
      name: name ?? shownName(ref, card, language),
      info: info,
      code: code ?? card.id,
      passcode: int.tryParse(card.passcode ?? '') == null ? null : card.passcode,
      artwork: artwork == null ? null : FileImage(artwork),
      language: language,
      onPart: onPart,
    );
  }
}
