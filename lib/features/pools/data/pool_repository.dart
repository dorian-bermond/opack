import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../domain/pool.dart';

/// Saved pools, as JSON files in the app support directory.
class PoolStore {
  PoolStore(this._directory);

  final Future<Directory> _directory;

  static Future<Directory> defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/pools');

  Future<List<Pool>> loadAll() async {
    final dir = await _directory;
    if (!await dir.exists()) return [];
    final pools = <Pool>[];
    await for (final file in dir.list()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      try {
        pools.add(Pool.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>));
      } on FormatException {
        // Skip a corrupt file rather than hiding every pool.
      }
    }
    return pools..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> save(Pool pool) async {
    final dir = await _directory;
    await dir.create(recursive: true);
    await File('${dir.path}/${pool.id}.json').writeAsString(jsonEncode(pool.toJson()));
  }

  Future<void> delete(String id) async {
    final file = File('${(await _directory).path}/$id.json');
    if (await file.exists()) await file.delete();
  }
}

final poolStoreProvider = Provider<PoolStore>((ref) => PoolStore(PoolStore.defaultDirectory()));

final poolsProvider = AsyncNotifierProvider<PoolsController, List<Pool>>(PoolsController.new);

class PoolsController extends AsyncNotifier<List<Pool>> {
  @override
  Future<List<Pool>> build() => ref.watch(poolStoreProvider).loadAll();

  /// Adds or replaces [pool] once the saved pools are loaded; the list
  /// updates at once, the file after.
  Future<void> save(Pool pool) async {
    final others = [...await future]..removeWhere((p) => p.id == pool.id);
    state = AsyncData([pool, ...others]);
    await ref.read(poolStoreProvider).save(pool);
  }

  /// Changes the pool [id] through [change] on its latest saved state,
  /// after any save already under way, so nothing of it is lost.
  Future<void> change(String id, Pool Function(Pool pool) change) async {
    await future;
    final current = state.value?.where((p) => p.id == id).firstOrNull;
    if (current != null) await save(change(current));
  }

  Future<void> remove(String id) async {
    state = AsyncData([...await future]..removeWhere((p) => p.id == id));
    await ref.read(poolStoreProvider).delete(id);
  }
}

/// The bundled sets a pool needs, keyed by code. The key lists the codes
/// comma-separated so equal requests share one load.
final poolSetsProvider =
    FutureProvider.family<Map<String, CardSet>, (Game, String)>((ref, key) async {
  final (game, codes) = key;
  final catalog = ref.watch(catalogRepositoryProvider);
  final known = {for (final set in catalog.setsFor(game)) set.code};
  final wanted = codes.split(',').where(known.contains).toList();
  final sets = await Future.wait([for (final code in wanted) catalog.loadSet(game, code)]);
  return {for (final set in sets) set.code: set};
});

(Game, String) poolSetsKey(Pool pool) => (pool.game, (pool.setCodes.toList()..sort()).join(','));
