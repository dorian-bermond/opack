import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../features/catalog/domain/models.dart';
import '../images/card_image_cache.dart';
import 'trimmed_image.dart';

/// The plain pack's width over height.
const packAspect = 180 / 280;

/// Whether a picture of this aspect ratio (width over height) looks like
/// a booster pack, a tall rectangle; a logo or a landscape does not.
bool isPackShaped(double aspect) => aspect >= 0.45 && aspect <= 0.85;

/// The aspect ratio (width over height) of a pack picture's subject, its
/// blank margins left out; the plain pack's until measured.
final coverAspectProvider = FutureProvider.family<double, String>((ref, path) => TrimmedImage.aspectOf(File(path)));

/// The pack picture a pool shows, as [BoosterCover] picks it: the user's
/// own (and whether it is [printed] on a plain pack), else the set's once
/// downloaded; no file for the plain pack or MtG card art.
({File? file, bool printed}) coverPicture(
  WidgetRef ref,
  BuildContext context, {
  CardSet? set,
  BoosterType? booster,
  String? custom,
  bool printed = false,
}) {
  if (custom != null && File(custom).existsSync()) return (file: File(custom), printed: printed);
  if (set == null) return (file: null, printed: false);
  final source = boosterImageSource(set, language: pictureLanguage(ref, context), booster: booster);
  final image = source == null ? null : ref.watch(cardImageProvider(source)).value;
  if (image == null || (set.game == Game.mtg && image.path.endsWith('-art.jpg'))) return (file: null, printed: false);
  return (file: image, printed: false);
}

/// The shape of the pack [cover] makes: its picture's when the picture is
/// shown as it is and looks like a pack, else the plain pack's (a picture
/// printed on a pack, not shaped like one, or not measured yet).
double packAspectOf(WidgetRef ref, ({File? file, bool printed}) cover) {
  final file = cover.file;
  if (file == null || cover.printed) return packAspect;
  final aspect = ref.watch(coverAspectProvider(file.path)).value;
  return aspect != null && isPackShaped(aspect) ? aspect : packAspect;
}

/// A sealed booster: the pack picture of [set] once downloaded (or, for MtG
/// sets without one, card art under the set name), else a plain pack
/// showing [label]. Without a set (random packs) always the plain pack.
/// A pack picture is shown without its blank margins, filling the box;
/// one not shaped like a pack (a set's logo) is printed on a plain pack
/// under the set's name, as is the user's own picture when [printed].
class BoosterCover extends ConsumerWidget {
  const BoosterCover({
    super.key,
    required this.set,
    required this.label,
    this.booster,
    this.custom,
    this.printed = false,
    this.width = 180,
    this.height = 280,
  });

  final CardSet? set;

  /// A picture of the user's own, as a file path, shown instead of the set's.
  final String? custom;

  /// Whether [custom] is printed on a plain pack rather than shown as it is.
  final bool printed;
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
    final own = custom != null && custom.existsSync();
    final picture = own ? custom : image;
    final name = set?.nameFor(Localizations.localeOf(context).languageCode) ?? label;
    final Widget front;
    // A picture of the pack stands alone; the plain pack, MtG's art and a
    // printed picture get a backdrop.
    var backdrop = false;
    if (picture == null) {
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
    } else if (!own && set!.game == Game.mtg && picture.path.endsWith('-art.jpg')) {
      backdrop = true;
      front = Stack(
        fit: StackFit.expand,
        children: [
          Image.file(picture, fit: BoxFit.cover),
          _banner(theme, name),
        ],
      );
    } else {
      final aspect = ref.watch(coverAspectProvider(picture.path)).value;
      if (own ? printed : aspect != null && !isPackShaped(aspect)) {
        // A logo or a landscape: printed on a plain pack under the name.
        backdrop = true;
        front = Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(width / 10, height / 12, width / 10, height / 4),
              child: TrimmedImage(picture, key: const Key('printedCover')),
            ),
            _banner(theme, name),
          ],
        );
      } else {
        // Product pictures come with blank margins around the pack: they are
        // cropped away so the pack fills the cover.
        front = TrimmedImage(picture, key: own ? const Key('customCover') : null);
      }
    }

    if (!backdrop) return SizedBox(width: width, height: height, child: front);
    return _pack(theme, front, hasPicture: image != null || own);
  }

  Widget _banner(ThemeData theme, String name) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Colors.black54,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ),
      );

  Widget _pack(ThemeData theme, Widget front, {required bool hasPicture}) {
    return Ink(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: hasPicture ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primary,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: front),
    );
  }
}
