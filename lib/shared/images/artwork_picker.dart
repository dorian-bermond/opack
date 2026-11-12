import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// A grid of the artworks of [card], the chosen one highlighted; tapping
/// one saves it on the pool, the card's own print clearing the choice.
class ArtworkPicker extends ConsumerWidget {
  const ArtworkPicker({super.key, required this.poolId, required this.card});

  final String poolId;
  final CardData card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final artworks = ref.watch(artworksProvider(artworkKeyOf(card)));

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
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  childAspectRatio: 63 / 112,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: found.length,
                itemBuilder: (context, i) => _ArtworkTile(
                  card: card,
                  artwork: found[i],
                  chosen: card.artwork == null ? found[i].own : card.artwork == found[i].key,
                  onTap: () => choose(found[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

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
