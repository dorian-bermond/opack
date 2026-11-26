import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../catalog/domain/models.dart';
import '../domain/protocol.dart';

/// Where a player stands with the room.
enum ClientStatus { connecting, lobby, sealed, draft, error, closed }

class ClientState {
  const ClientState({
    required this.status,
    this.seat,
    this.game,
    this.poolName,
    this.players = const [],
    this.packs,
    this.draft,
    this.error,
  });

  final ClientStatus status;
  final int? seat;
  final Game? game;
  final String? poolName;
  final List<RoomPlayer> players;

  /// The packs dealt to this player in a sealed game.
  final List<List<CardData>>? packs;

  /// This player's seat in a draft.
  final SeatView? draft;
  final String? error;

  ClientState copyWith({
    ClientStatus? status,
    int? seat,
    Game? game,
    String? poolName,
    List<RoomPlayer>? players,
    List<List<CardData>>? packs,
    SeatView? draft,
    String? error,
  }) =>
      ClientState(
        status: status ?? this.status,
        seat: seat ?? this.seat,
        game: game ?? this.game,
        poolName: poolName ?? this.poolName,
        players: players ?? this.players,
        packs: packs ?? this.packs,
        draft: draft ?? this.draft,
        error: error ?? this.error,
      );
}

/// A player's side of a room: joins a host by address and code, then
/// follows what the host sends.
class RoomClient {
  final state = ValueNotifier<ClientState>(const ClientState(status: ClientStatus.connecting));
  WebSocket? _socket;
  bool _closed = false;

  void _update(ClientState next) {
    if (!_closed) state.value = next;
  }

  /// Connects to `host:port` and asks to join as [name] with [code].
  Future<void> connect(String address, {required String name, required String code}) async {
    _update(const ClientState(status: ClientStatus.connecting));
    try {
      final socket = await WebSocket.connect('ws://$address/').timeout(const Duration(seconds: 8));
      _socket = socket;
      socket.add(encodeMessage('join', {'name': name, 'code': code, 'version': protocolVersion}));
      socket.listen(_receive, onDone: () {
        if (!_closed && state.value.status != ClientStatus.error) {
          _update(state.value.copyWith(status: ClientStatus.closed));
        }
      }, onError: (Object e) => _update(state.value.copyWith(status: ClientStatus.error, error: '$e')));
    } on Object catch (e) {
      _update(ClientState(status: ClientStatus.error, error: '$e'));
    }
  }

  void _receive(Object? data) {
    final message = decodeMessage(data);
    if (message == null || _closed) return;
    final s = state.value;
    switch (message['type']) {
      case 'welcome':
        _update(s.copyWith(
          status: ClientStatus.lobby,
          seat: message['seat'] as int,
          game: Game.values.asNameMap()[message['game']],
          poolName: message['pool'] as String?,
          players: _players(message),
        ));
      case 'players':
        _update(s.copyWith(players: _players(message)));
      case 'sealed':
        _update(s.copyWith(
          status: ClientStatus.sealed,
          packs: [for (final pack in message['packs'] as List) cardsFromJson(pack)],
        ));
      case 'draft':
        _update(s.copyWith(status: ClientStatus.draft, draft: SeatView.fromJson(message)));
      case 'error':
        _update(s.copyWith(status: ClientStatus.error, error: '${message['message']}'));
    }
  }

  List<RoomPlayer> _players(Map<String, dynamic> message) =>
      [for (final p in (message['players'] as List? ?? const []).cast<Map<String, dynamic>>()) playerFromJson(p)];

  /// Picks (or burns) [cardId] from the pack in hand.
  void pick(String cardId) => _socket?.add(encodeMessage('pick', {'card': cardId}));

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _socket?.close();
    _socket = null;
    state.dispose();
  }
}
