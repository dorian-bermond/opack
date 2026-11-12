import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../features/catalog/domain/models.dart';
import '../images/card_image_cache.dart';

/// A sealed booster: the pack picture of [set] once downloaded (or, for MtG
/// sets without one, card art under the set name), else a plain pack
/// showing [label]. Without a set (random packs) always the plain pack.
class BoosterCover extends ConsumerWidget {
  const BoosterCover({
    super.key,
    required this.set,
    required this.label,
    this.booster,
    this.width = 180,
    this.height = 280,
  });

  final CardSet? set;
  final String label;
  final BoosterType? booster;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final language = pictureLanguage(ref, context);
    final set = this.set;
    final source = set == null ? null : boosterImageSource(set, language: language, booster: booster);
    final image = source == null ? null : ref.watch(cardImageProvider(source)).value;

    final Widget front;
    if (image == null) {
      front = Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            set?.displayCode ?? label,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimary),
          ),
        ),
      );
    } else if (set!.game == Game.mtg && image.path.endsWith('-art.jpg')) {
      front = Stack(
        fit: StackFit.expand,
        children: [
          Image.file(image, fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.black54,
              child: Text(
                set.nameFor(Localizations.localeOf(context).languageCode),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      );
    } else {
      front = Padding(
        padding: const EdgeInsets.all(8),
        child: Image.file(image, fit: BoxFit.contain),
      );
    }

    return Ink(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: image == null ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: front),
    );
  }
}
