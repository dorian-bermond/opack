import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../domain/cube.dart';
import '../domain/cube_parsers.dart';

/// Imported cubes, saved as JSON files in the app support directory.
class CubeStore {
  CubeStore(this._directory);

  final Future<Directory> _directory;

  static Future<Directory> defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/cubes');

  Future<List<Cube>> loadAll() async {
    final dir = await _directory;
    if (!await dir.exists()) return [];
    final cubes = <Cube>[];
    await for (final file in dir.list()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      try {
        cubes.add(Cube.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>));
      } on FormatException {
        // Skip a corrupt file rather than hiding every cube.
      }
    }
    return cubes..sort((a, b) => b.importedAt.compareTo(a.importedAt));
  }

  Future<void> save(Cube cube) async {
    final dir = await _directory;
    await dir.create(recursive: true);
    await File('${dir.path}/${cube.id}.json').writeAsString(jsonEncode(cube.toJson()));
  }

  Future<void> delete(String id) async {
    final file = File('${(await _directory).path}/$id.json');
    if (await file.exists()) await file.delete();
  }
}

final cubeStoreProvider = Provider<CubeStore>((ref) => CubeStore(CubeStore.defaultDirectory()));

final cubesProvider = AsyncNotifierProvider<CubesController, List<Cube>>(CubesController.new);

class CubesController extends AsyncNotifier<List<Cube>> {
  @override
  Future<List<Cube>> build() => ref.watch(cubeStoreProvider).loadAll();

  Future<void> add(Cube cube) async {
    await ref.read(cubeStoreProvider).save(cube);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await ref.read(cubeStoreProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}

class CubeImportException implements Exception {
  CubeImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Downloads a CubeCobra cube; French names come from the bundled MtG sets.
Future<Cube> importCubeCobra(String input, CatalogRepository catalog, {http.Client? client}) async {
  final id = cubeCobraId(input);
  if (id.isEmpty) throw CubeImportException('Empty cube ID');
  final uri = Uri.https('cubecobra.com', '/cube/api/cubeJSON/${Uri.encodeComponent(id)}');
  final response = await (client ?? http.Client()).get(uri);
  if (response.statusCode != 200) {
    throw CubeImportException('CubeCobra: HTTP ${response.statusCode} for "$id"');
  }
  final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  final parsed = parseCubeCobra(json, await mtgFrenchNames(catalog));
  if (parsed.cards.isEmpty) throw CubeImportException('Cube "$id" has no cards');
  return Cube(
    id: 'mtg-${DateTime.now().microsecondsSinceEpoch}',
    game: Game.mtg,
    name: parsed.name.isEmpty ? id : parsed.name,
    source: 'CubeCobra: $id',
    importedAt: DateTime.now(),
    cards: parsed.cards,
  );
}

Map<String, String>? _frenchCache;

/// English -> French card names across every bundled MtG set.
Future<Map<String, String>> mtgFrenchNames(CatalogRepository catalog) async {
  if (_frenchCache case final names?) return names;
  final names = <String, String>{};
  for (final summary in catalog.setsFor(Game.mtg)) {
    final set = await catalog.loadSet(Game.mtg, summary.code);
    for (final card in set.cards) {
      if ((card.names['en'], card.names['fr']) case (final en?, final fr?)) {
        names[en] = fr;
      }
    }
  }
  return _frenchCache = names;
}

YgoCardDatabase? _ygoDatabase;

Future<YgoCardDatabase> ygoCardDatabase(AssetBundle bundle) async =>
    _ygoDatabase ??= YgoCardDatabase(
        jsonDecode(await bundle.loadString('assets/cards/ygo_cards.json', cache: false)) as List);

/// Builds a Yu-Gi-Oh! cube from a `.ydk` or card-name list.
Future<({Cube cube, List<String> unresolved})> importYgoList({
  required String name,
  required String fileName,
  required String text,
  required AssetBundle bundle,
}) async {
  final parsed = parseYgoList(text, await ygoCardDatabase(bundle));
  if (parsed.cards.isEmpty) throw CubeImportException('No known card in "$fileName"');
  return (
    cube: Cube(
      id: 'ygo-${DateTime.now().microsecondsSinceEpoch}',
      game: Game.ygo,
      name: name,
      source: fileName,
      importedAt: DateTime.now(),
      cards: parsed.cards,
    ),
    unresolved: parsed.unresolved,
  );
}
