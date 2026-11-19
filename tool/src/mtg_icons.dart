// Expansion symbols of the bundled MtG sets, from Scryfall's set list:
//   assets/sets/mtg/icons/<CODE>.svg    one symbol per set that has one
// and an `icon` path in each set file.

import 'dart:convert';
import 'dart:io';

import 'common.dart';

/// Downloads the symbol of every set file under `assets/sets/mtg` whose
/// code Scryfall lists, and writes its path into the set file. Returns
/// how many sets got one.
Future<int> importMtgIcons(CachedHttp http) async {
  final listing = jsonDecode((await http.get(Uri.https('api.scryfall.com', '/sets'), headers: const {'Accept': 'application/json'}))!) as Map<String, dynamic>;
  final icons = {
    for (final set in (listing['data'] as List).cast<Map<String, dynamic>>())
      (set['code'] as String).toUpperCase(): set['icon_svg_uri'] as String,
  };
  final files = Directory('assets/sets/mtg').listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
  var count = 0;
  for (final file in files) {
    final set = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final code = set['code'] as String;
    final uri = icons[code];
    if (uri == null) {
      stderr.writeln('$code: no symbol on Scryfall');
      continue;
    }
    final svg = await http.get(Uri.parse(uri).replace(query: ''));
    if (svg == null) continue;
    final icon = File('assets/sets/mtg/icons/${assetFileName(code)}.svg');
    await icon.parent.create(recursive: true);
    await icon.writeAsString(svg);
    final path = icon.path.replaceAll(r'\', '/');
    if (set['icon'] != path) {
      set['icon'] = path;
      await file.writeAsString(jsonEncode(set));
    }
    count++;
  }
  stdout.writeln('Symbols: $count sets');
  return count;
}
