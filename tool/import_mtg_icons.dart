// Fetches the expansion symbols of the bundled MtG sets from Scryfall
// (see src/mtg_icons.dart) and rebuilds the index:
//
//   dart run tool/import_mtg_icons.dart

import 'src/common.dart';
import 'src/mtg_icons.dart';

Future<void> main() async {
  final http = CachedHttp('.cache/mtg');
  try {
    await importMtgIcons(http);
    await rebuildIndex();
  } finally {
    http.close();
  }
}
