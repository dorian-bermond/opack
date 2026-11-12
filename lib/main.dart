import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/card_text/data/card_text_repository.dart';
import 'features/catalog/data/catalog_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (catalog, prefs) = await (
    AssetCatalogRepository.load(rootBundle),
    SharedPreferences.getInstance(),
  ).wait;
  runApp(ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(catalog),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const OpackApp(),
  ));
}
