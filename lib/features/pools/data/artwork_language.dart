import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/images/artwork_search.dart';
import '../../cube/data/cube_repository.dart';
import '../domain/play_pool.dart';
import 'pool_repository.dart';

/// Moves the artworks chosen in the pools along with the pictures' language.
final artworkLanguageSwitchProvider = Provider<ArtworkLanguageSwitch>(ArtworkLanguageSwitch.new);

class ArtworkLanguageSwitch {
  ArtworkLanguageSwitch(this._ref);

  final Ref _ref;

  /// In every pool, swaps each chosen artwork printed in [from] for the same
  /// print in [to] (see [artworkIn]). Artworks in another language, and the
  /// ones without a print in [to], stay. A card whose scans cannot be
  /// fetched is skipped. Answers how many artworks changed.
  Future<int> run({required String from, required String to}) async {
    final search = _ref.read(artworkSearchProvider);
    if (from == to || search == null) return 0;
    final cubes = {for (final cube in await _ref.read(cubesProvider.future)) cube.id: cube};
    var changed = 0;
    for (final pool in await _ref.read(poolsProvider.future)) {
      if (pool.artworks.isEmpty) continue;
      // Card id -> (the artwork it had, the one it takes; `null` its own print).
      final swaps = <String, (String, String?)>{};
      try {
        final sets = await _ref.read(poolSetsProvider(poolSetsKey(pool)).future);
        for (final (:card, listed: _) in PlayPool.resolve(pool, sets: sets, cubes: cubes).entries) {
          final chosen = card.artwork;
          if (chosen == null) continue;
          try {
            // Asked directly: the provider would retry a failing card for long.
            final found = await search.alternatives(card);
            final current = found.where((a) => a.key == chosen).firstOrNull;
            if (current == null || current.language != from) continue;
            final next = artworkIn(found, current, to);
            if (next != null) swaps[card.id] = (chosen, next.own ? null : next.key);
          } on Exception {
            // Offline or the site refused: this card keeps its artwork.
          }
        }
      } on Exception {
        continue;
      }
      if (swaps.isEmpty) continue;
      await _ref.read(poolsProvider.notifier).change(pool.id, (latest) {
        for (final MapEntry(key: cardId, value: (previous, next)) in swaps.entries) {
          // Only where the choice has not changed meanwhile.
          if (latest.artworks[cardId] == previous) {
            latest = latest.withArtwork(cardId, next);
            changed++;
          }
        }
        return latest;
      });
    }
    return changed;
  }
}
