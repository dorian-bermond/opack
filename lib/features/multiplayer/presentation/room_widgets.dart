import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/protocol.dart';

/// The people and bots seated in a room, [self] marked.
class PlayersList extends StatelessWidget {
  const PlayersList({super.key, required this.players, this.self});

  final List<RoomPlayer> players;
  final int? self;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.players, style: theme.textTheme.labelLarge),
        for (final p in players)
          ListTile(
            key: ValueKey('player-${p.seat}'),
            dense: true,
            leading: Icon(p.bot ? Icons.smart_toy_outlined : Icons.person_outline),
            title: Text(p.name + (p.seat == self ? ' (${l10n.you})' : '')),
            subtitle: p.bot
                ? Text(l10n.bot)
                : p.connected
                    ? null
                    : Text(l10n.disconnected, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}
