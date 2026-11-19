import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../features/catalog/domain/models.dart';
import '../images/card_image_cache.dart';
import 'trimmed_image.dart';

/// The aspect ratio (width over height) of a pack picture's subject, its
/// blank margins left out; the plain pack's until measured.
final coverAspectProvider = FutureProvider.family<double, String>((ref, path) => TrimmedImage.aspectOf(File(path)));

/// The pack picture a pool shows, as [BoosterCover] picks it: the user's
/// own, else the set's once downloaded; `null` for the plain pack or MtG
/// card art, which get a frame of the plain pack's shape.
File? coverPicture(WidgetRef ref, BuildContext context, {CardSet? set, BoosterType? booster, String? custom}) {
  if (custom != null && File(custom).existsSync()) return File(custom);
  if (set == null) return null;
  final source = boosterImageSource(set, language: pictureLanguage(ref, context), booster: booster);
  final image = source == null ? null : ref.watch(cardImageProvider(source)).value;
  if (image == null || (set.game == Game.mtg && image.path.endsWith('-art.jpg'))) return null;
  return image;
}

/// A sealed booster: the pack picture of [set] once downloaded (or, for MtG
/// sets without one, card art under the set name), else a plain pack
/// showing [label]. Without a set (random packs) always the plain pack.
/// A pack picture is shown without its blank margins, filling the box.
class BoosterCover extends ConsumerWidget {
  const BoosterCover({
    super.key,
    required this.set,
    required this.label,
    this.booster,
    this.custom,
    this.width = 180,
    this.height = 280,
  });

  final CardSet? set;

  /// A picture of the user's own, as a file path, shown instead of the set's.
  final String? custom;
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

    final custom = this.custom == null ? null : File(this.custom!);
    final Widget front;
    // A picture of the pack stands alone; the plain pack and MtG's art get a backdrop.
    var backdrop = false;
    if (custom != null && custom.existsSync()) {
      front = TrimmedImage(custom, key: const Key('customCover'));
    } else if (image == null) {
      backdrop = true;
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
      backdrop = true;
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
      // Product pictures come with blank margins around the pack: they are
      // cropped away so the pack fills the cover.
      front = TrimmedImage(image);
    }

    if (!backdrop) return SizedBox(width: width, height: height, child: front);
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
