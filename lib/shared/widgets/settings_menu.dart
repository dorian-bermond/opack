import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../l10n/app_localizations.dart';

/// App bar button opening the settings page.
class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        key: const Key('settingsButton'),
        icon: const Icon(Icons.settings),
        tooltip: AppLocalizations.of(context).settings,
        onPressed: () => context.push(settingsPath),
      );
}
