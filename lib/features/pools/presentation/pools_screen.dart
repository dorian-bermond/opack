import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/settings_menu.dart';
import '../../catalog/domain/models.dart';
import '../../catalog/presentation/home_screen.dart';
import 'pool_list.dart';

/// The main screen of a game: its pools, where every pack is opened and
/// every sealed or draft is played from.
class PoolsScreen extends StatelessWidget {
  const PoolsScreen({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(game.label(l10n)),
        actions: [
          IconButton(
            tooltip: l10n.tabCubes,
            icon: const Icon(Icons.view_module),
            onPressed: () => context.go(cubesPath(game)),
          ),
          const SettingsMenu(),
        ],
      ),
      body: PoolList(game: game),
    );
  }
}
