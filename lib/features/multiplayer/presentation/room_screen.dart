import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../card_text/data/card_text_repository.dart';
import '../../pools/domain/play_pool.dart';
import '../../pools/domain/pool.dart';
import '../../pools/presentation/pool_loader.dart';
import '../../sealed/presentation/sealed_screen.dart';
import '../data/room_host.dart';
import '../domain/protocol.dart';
import 'draft_table_view.dart';
import 'room_widgets.dart';

/// Hosts a room on the local network for [poolId]: the lobby with the
/// address and code others join by, then the game, the host playing seat
/// 0 on this device.
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key, required this.poolId});

  final String poolId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => _Room(play: pool),
      );
}

class _Room extends ConsumerStatefulWidget {
  const _Room({required this.play});

  final PlayPool play;

  @override
  ConsumerState<_Room> createState() => _RoomState();
}

class _RoomState extends ConsumerState<_Room> {
  static const _nameKey = 'playerName';

  RoomHost? _host;
  List<String> _addresses = const [];
  String? _error;
  PlayFormat? _format;
  late int _seats;
  late final _name = TextEditingController(text: ref.read(sharedPreferencesProvider).getString(_nameKey) ?? '');

  @override
  void initState() {
    super.initState();
    _format = widget.play.pool.playFormats.firstOrNull;
    _seats = _format == null ? 2 : widget.play.seatsForFormat(_format!);
  }

  @override
  void dispose() {
    _name.dispose();
    _host?.stop();
    super.dispose();
  }

  Future<void> _open() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref.read(sharedPreferencesProvider).setString(_nameKey, name);
    final host = RoomHost(play: widget.play, hostName: name);
    try {
      await host.start();
      final addresses = await host.addresses();
      setState(() {
        _host = host;
        _addresses = addresses;
      });
    } on Object catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _start() {
    final host = _host;
    final format = _format;
    if (host == null || format == null) return;
    switch (format.kind) {
      case FormatKind.sealed:
        host.startSealed(format);
      case FormatKind.draft:
        host.startDraft(format, seats: _seats);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final host = _host;
    if (host == null) return _setup(context, l10n);
    return ValueListenableBuilder<RoomState>(
      valueListenable: host.state,
      builder: (context, state, _) => switch (state.phase) {
        RoomPhase.lobby => _lobby(context, l10n, host, state),
        RoomPhase.sealed => SealedView(
            title: widget.play.pool.name,
            subtitle: l10n.packsCount(state.hostPacks!.length),
            deal: () => state.hostPacks!,
            canRedeal: false,
          ),
        RoomPhase.draft => DraftTableView(seat: _HostSeat(host.state), onPick: (id) => host.pick(0, id)),
      },
    );
  }

  Widget _setup(BuildContext context, AppLocalizations l10n) {
    final play = widget.play;
    final formats = play.pool.playFormats;
    final people = 1;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playTogether)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.hostRoomHint),
          const SizedBox(height: 16),
          TextField(
            key: const Key('hostName'),
            controller: _name,
            decoration: InputDecoration(labelText: l10n.yourName, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          // Formats are compared by id: the pool builds its defaults anew each time.
          DropdownButtonFormField<String>(
            key: const Key('hostFormat'),
            initialValue: _format?.id,
            decoration: InputDecoration(labelText: l10n.formats, border: const OutlineInputBorder()),
            items: [
              for (final f in formats)
                DropdownMenuItem(
                  value: f.id,
                  child: Text('${f.name} · ${f.kind == FormatKind.sealed ? l10n.modeSealed : l10n.modeDraft}'),
                ),
            ],
            onChanged: (id) => setState(() {
              final f = formats.where((f) => f.id == id).firstOrNull;
              _format = f;
              if (f != null) _seats = play.seatsForFormat(f).clamp(people, 8);
            }),
          ),
          if (_format?.kind == FormatKind.draft) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.seats),
                Expanded(
                  child: Slider(
                    key: const Key('hostSeats'),
                    min: 2,
                    max: play.seatsForFormat(_format!).clamp(2, 8).toDouble(),
                    divisions: (play.seatsForFormat(_format!).clamp(2, 8) - 2).clamp(1, 6),
                    value: _seats.clamp(2, play.seatsForFormat(_format!).clamp(2, 8)).toDouble(),
                    label: '$_seats',
                    onChanged: (v) => setState(() => _seats = v.round()),
                  ),
                ),
                Text('$_seats'),
              ],
            ),
            Text(l10n.seatsHint, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('hostOpen'),
            icon: const Icon(Icons.wifi_tethering),
            label: Text(l10n.openRoom),
            onPressed: _format == null ? null : _open,
          ),
        ],
      ),
    );
  }

  Widget _lobby(BuildContext context, AppLocalizations l10n, RoomHost host, RoomState state) {
    final theme = Theme.of(context);
    final format = _format!;
    final people = state.players.where((p) => !p.bot).length;
    final canStart = format.kind == FormatKind.sealed
        ? widget.play.canPlay(format, players: people)
        : widget.play.canPlay(format, players: _seats);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playTogether)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.roomOpenHint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(l10n.roomAddress, style: theme.textTheme.labelLarge),
          for (final address in _addresses)
            ListTile(
              key: ValueKey('address-$address'),
              dense: true,
              title: SelectableText(address, style: theme.textTheme.titleMedium),
              trailing: IconButton(
                tooltip: l10n.copy,
                icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(ClipboardData(text: address)),
              ),
            ),
          if (_addresses.isEmpty) Text(l10n.noAddress, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          Text(l10n.roomCode, style: theme.textTheme.labelLarge),
          SelectableText(host.code, key: const Key('roomCode'), style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          PlayersList(players: state.players, self: 0),
          const SizedBox(height: 16),
          Text(
            '${format.name} · ${format.kind == FormatKind.sealed ? l10n.modeSealed : l10n.modeDraft}'
            '${format.kind == FormatKind.draft ? ' · ${l10n.seatsCount(_seats)}' : ''}',
          ),
          if (!canStart)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.roomTooSmall, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('hostStart'),
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.startGame),
            onPressed: canStart ? _start : null,
          ),
        ],
      ),
    );
  }
}

/// The host's seat out of the room's state, as a listenable of its own.
class _HostSeat extends ValueNotifier<SeatView?> {
  _HostSeat(this.source) : super(source.value.hostSeat) {
    source.addListener(_sync);
  }

  final ValueListenable<RoomState> source;

  void _sync() => value = source.value.hostSeat;

  @override
  void dispose() {
    source.removeListener(_sync);
    super.dispose();
  }
}
