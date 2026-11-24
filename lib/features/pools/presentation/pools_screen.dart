import '../../../shared/widgets/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/settings_menu.dart';
import 'pool_list.dart';

/// The main screen: every pool of every game, where every pack is opened
/// and every sealed or draft is played from.
class PoolsScreen extends StatelessWidget {
  const PoolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.tabCubes,
            icon: const Icon(Icons.view_module),
            onPressed: () => context.go(cubesPath),
          ),
          const SettingsMenu(),
        ],
      ),
      body: const Column(
        children: [
          UpdateBanner(),
          Expanded(child: PoolList()),
        ],
      ),
    );
  }
}
