import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../features/catalog/domain/models.dart';
import '../../features/pools/data/pool_repository.dart';
import '../../l10n/app_localizations.dart';
import 'artwork_search.dart';
import 'card_image_cache.dart';

/// Lets the user pick, among every artwork [card] exists with, the one the
/// pool [poolId] shows it with. Answers `true` when the pool changed.
Future<bool> pickArtwork(BuildContext context, {required String poolId, required CardData card}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: ArtworkPicker(poolId: poolId, card: card),
    ),
  );
  return changed ?? false;
}

/// The artworks of [card] in grids by language, the pictures' language
/// first, then English, then the others; the one the card is shown with
/// is marked. Tapping one saves it on the pool, the card's own print
/// clearing the choice.
class ArtworkPicker extends ConsumerWidget {
  const ArtworkPicker({super.key, required this.poolId, required this.card});

  final String poolId;
  final CardData card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final artworks = ref.watch(artworksProvider(artworkKeyOf(card)));
    final preferred = pictureLanguage(ref, context);

    Future<void> choose(Artwork artwork) async {
      final pools = ref.read(poolsProvider.notifier);
      final pool = (await ref.read(poolsProvider.future)).where((p) => p.id == poolId).firstOrNull;
      if (pool == null) return;
      await pools.save(pool.withArtwork(card.id, artwork.own ? null : artwork.key));
      if (context.mounted) Navigator.pop(context, true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.swapArtwork, style: theme.textTheme.titleLarge),
        ),
        Expanded(
          child: artworks.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.artworkLoadFailed('$error'), textAlign: TextAlign.center),
            ),
            data: (found) {
              if (found.length < 2) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.noOtherArtwork, textAlign: TextAlign.center),
                );
              }
              final shown = shownArtwork(found, artwork: card.artwork, language: preferred);
              final groups = groupedByLanguage(found, preferred: preferred);
              return CustomScrollView(
                slivers: [
                  for (final MapEntry(key: language, value: artworks) in groups.entries) ...[
                    if (language != null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            languageName(l10n, language),
                            key: ValueKey('artworkLanguage-$language'),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      sliver: SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          childAspectRatio: 63 / 112,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: artworks.length,
                        itemBuilder: (context, i) => _ArtworkTile(
                          card: card,
                          artwork: artworks[i],
                          chosen: artworks[i].key == shown?.key,
                          onTap: () => choose(artworks[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The artwork the card is shown with: the chosen [artwork], else its
/// own print in the pictures' [language], else its own print.
Artwork? shownArtwork(List<Artwork> found, {String? artwork, required String language}) {
  if (artwork != null) return found.where((a) => a.key == artwork).firstOrNull;
  return found.where((a) => a.samePrint && a.language == language).firstOrNull ??
      found.where((a) => a.own).firstOrNull;
}

/// The artworks by language: the [preferred] one first, then English,
/// then the others by code, then the ones serving every language (`null`).
Map<String?, List<Artwork>> groupedByLanguage(List<Artwork> found, {required String preferred}) {
  final languages = {for (final a in found) a.language};
  int rank(String? l) => l == preferred ? 0 : l == 'en' ? 1 : l == null ? 3 : 2;
  final ordered = languages.toList()..sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : (a ?? '').compareTo(b ?? ''));
  return {for (final l in ordered) l: [for (final a in found) if (a.language == l) a]};
}

/// A language as the user reads it: the ones the app knows by name, the
/// others by code.
String languageName(AppLocalizations l10n, String code) => switch (code) {
      'en' => l10n.languageEnglish,
      'fr' => l10n.languageFrench,
      _ => code.toUpperCase(),
    };

class _ArtworkTile extends ConsumerWidget {
  const _ArtworkTile({required this.card, required this.artwork, required this.chosen, required this.onTap});

  final CardData card;
  final Artwork artwork;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final image = ref.watch(cardImageProvider(artworkImageSource(card, artwork.key, small: true))).value;
    return Card(
      key: ValueKey('artwork-${artwork.key}'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: chosen ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: chosen ? 3 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 63 / 88,
              child: image != null
                  ? Image.file(image, fit: BoxFit.cover)
                  : ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.image_outlined)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Text(
                [
                  if (artwork.own) l10n.artworkOwn else artwork.label,
                  if (chosen) l10n.artworkChosen,
                ].join(' · '),
                style: theme.textTheme.labelSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
