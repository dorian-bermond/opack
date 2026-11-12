import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/models.dart';

extension GamePresentation on Game {
  String label(AppLocalizations l10n) => switch (this) {
        Game.mtg => l10n.gameMtg,
        Game.ygo => l10n.gameYgo,
      };

  /// A short tag for lists mixing both games.
  String get shortLabel => switch (this) {
        Game.mtg => 'MTG',
        Game.ygo => 'YGO',
      };
}

/// Asks which game, for anything created outside of a pool.
Future<Game?> pickGame(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<Game>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(l10n.chooseGame, style: Theme.of(context).textTheme.titleMedium)),
          for (final game in Game.values)
            ListTile(
              leading: const Icon(Icons.style),
              title: Text(game.label(l10n)),
              onTap: () => Navigator.pop(context, game),
            ),
        ],
      ),
    ),
  );
}
