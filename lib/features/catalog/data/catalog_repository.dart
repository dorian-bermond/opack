import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

abstract interface class CatalogRepository {
  /// Sets of [game], newest first.
  List<SetSummary> setsFor(Game game);
  Future<CardSet> loadSet(Game game, String code);
}

/// Overridden in `main()` with the catalog loaded at startup.
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => throw UnimplementedError('catalogRepositoryProvider not loaded'),
);

final cardSetProvider =
    FutureProvider.family<CardSet, (Game, String)>((ref, key) {
  final (game, code) = key;
  return ref.watch(catalogRepositoryProvider).loadSet(game, code);
});

/// Reads `assets/sets/index.json` up front and each set file on demand.
class AssetCatalogRepository implements CatalogRepository {
  AssetCatalogRepository._(this._bundle, this._sets);

  static const indexPath = 'assets/sets/index.json';

  static Future<AssetCatalogRepository> load(AssetBundle bundle) async {
    final index = jsonDecode(await bundle.loadString(indexPath)) as List;
    final sets = [
      for (final entry in index) SetSummary.fromJson(entry as Map<String, dynamic>),
    ]..sort(_newestFirst);
    return AssetCatalogRepository._(bundle, sets);
  }

  final AssetBundle _bundle;
  final List<SetSummary> _sets;
  final Map<String, Future<CardSet>> _loaded = {};

  @override
  List<SetSummary> setsFor(Game game) =>
      _sets.where((set) => set.game == game).toList();

  @override
  Future<CardSet> loadSet(Game game, String code) =>
      _loaded.putIfAbsent('${game.name}/$code', () async {
        final summary = _sets.firstWhere(
          (set) => set.game == game && set.code == code,
          orElse: () => throw ArgumentError('Unknown set ${game.name}/$code'),
        );
        final text = await _bundle.loadString(summary.assetPath, cache: false);
        return CardSet.fromJson(jsonDecode(text) as Map<String, dynamic>);
      });
}

int _newestFirst(SetSummary a, SetSummary b) {
  final byDate = (b.releaseDate ?? DateTime(0)).compareTo(a.releaseDate ?? DateTime(0));
  return byDate != 0 ? byDate : a.code.compareTo(b.code);
}
