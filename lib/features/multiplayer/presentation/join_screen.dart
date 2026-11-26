import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../card_text/data/card_text_repository.dart';
import '../../sealed/presentation/sealed_screen.dart';
import '../data/room_client.dart';
import '../domain/protocol.dart';
import 'draft_table_view.dart';
import 'room_widgets.dart';

/// Joins a room hosted on the local network: one's name, the host's
/// address and the room code, then the lobby and the game as the host
/// runs it.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  static const _nameKey = 'playerName';

  late final _name = TextEditingController(text: ref.read(sharedPreferencesProvider).getString(_nameKey) ?? '');
  final _address = TextEditingController();
  final _code = TextEditingController();
  RoomClient? _client;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _code.dispose();
    _client?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    final name = _name.text.trim();
    final address = _address.text.trim();
    final code = _code.text.trim().toUpperCase();
    if (name.isEmpty || address.isEmpty || code.isEmpty) return;
    await ref.read(sharedPreferencesProvider).setString(_nameKey, name);
    final client = RoomClient();
    setState(() => _client = client);
    await client.connect(address, name: name, code: code);
  }

  void _leave() {
    _client?.close();
    setState(() => _client = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final client = _client;
    if (client == null) return _form(context, l10n);
    return ValueListenableBuilder<ClientState>(
      valueListenable: client.state,
      builder: (context, state, _) => switch (state.status) {
        ClientStatus.connecting => Scaffold(
            appBar: AppBar(title: Text(l10n.joinRoom)),
            body: const Center(child: CircularProgressIndicator()),
          ),
        ClientStatus.lobby => Scaffold(
            appBar: AppBar(title: Text(state.poolName ?? l10n.joinRoom)),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.waitingForHost, key: const Key('waitingForHost')),
                const SizedBox(height: 12),
                PlayersList(players: state.players, self: state.seat),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _leave, child: Text(l10n.leaveRoom)),
              ],
            ),
          ),
        ClientStatus.sealed => SealedView(
            title: state.poolName ?? l10n.sealedPool,
            subtitle: l10n.packsCount(state.packs!.length),
            deal: () => state.packs!,
            canRedeal: false,
          ),
        ClientStatus.draft => DraftTableView(seat: _SeatOf(client.state), onPick: client.pick),
        ClientStatus.error || ClientStatus.closed => Scaffold(
            appBar: AppBar(title: Text(l10n.joinRoom)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.status == ClientStatus.closed ? l10n.roomClosed : l10n.connectionFailed(_reason(l10n, state.error)),
                    key: const Key('joinError'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _leave, child: Text(l10n.joinAgain)),
                ],
              ),
            ),
          ),
      },
    );
  }

  String _reason(AppLocalizations l10n, String? error) => switch (error) {
        'code' => l10n.wrongRoomCode,
        'started' => l10n.roomStarted,
        final e? => e,
        null => '',
      };

  Widget _form(BuildContext context, AppLocalizations l10n) => Scaffold(
        appBar: AppBar(title: Text(l10n.joinRoom)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.joinRoomHint),
            const SizedBox(height: 16),
            TextField(
              key: const Key('joinName'),
              controller: _name,
              decoration: InputDecoration(labelText: l10n.yourName, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('joinAddress'),
              controller: _address,
              decoration: InputDecoration(labelText: l10n.roomAddress, hintText: '192.168.1.10:51234', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('joinCode'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l10n.roomCode, border: const OutlineInputBorder()),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('joinConnect'),
              icon: const Icon(Icons.login),
              label: Text(l10n.joinRoom),
              onPressed: _connect,
            ),
          ],
        ),
      );
}

/// The draft seat out of the client's state, as a listenable of its own.
class _SeatOf extends ValueNotifier<SeatView?> {
  _SeatOf(this.source) : super(source.value.draft) {
    source.addListener(_sync);
  }

  final ValueListenable<ClientState> source;

  void _sync() => value = source.value.draft;

  @override
  void dispose() {
    source.removeListener(_sync);
    super.dispose();
  }
}
