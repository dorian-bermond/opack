import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/settings_menu.dart';
import '../domain/models.dart';

extension GamePresentation on Game {
  String label(AppLocalizations l10n) => switch (this) {
        Game.mtg => l10n.gameMtg,
        Game.ygo => l10n.gameYgo,
      };
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [SettingsMenu()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.chooseGame,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              for (final game in Game.values)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.style),
                    title: Text(game.label(l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/game/${game.name}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
