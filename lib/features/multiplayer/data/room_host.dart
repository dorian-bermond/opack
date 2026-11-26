import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../catalog/domain/models.dart';
import '../../draft/domain/draft_session.dart';
import '../../packs/domain/pack_source.dart';
import '../../pools/domain/play_pool.dart';
import '../../pools/domain/pool.dart';
import '../domain/multi_draft.dart';
import '../domain/protocol.dart';

/// Whether an IPv4 address is Tailscale's (the 100.64.0.0/10 range it
/// hands out): one that works across the internet, not only on the
/// local network.
bool isTailscaleAddress(String address) {
  final parts = address.split(':').first.split('.');
  if (parts.length != 4) return false;
  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  return first == 100 && second != null && second >= 64 && second <= 127;
}

/// Where a room stands.
enum RoomPhase { lobby, sealed, draft }

/// The room as the host sees it: the players seated, the game on and
/// what the host's own seat holds.
class RoomState {
  const RoomState({
    required this.phase,
    required this.players,
    this.format,
    this.hostPacks,
    this.hostSeat,
  });

  final RoomPhase phase;
  final List<RoomPlayer> players;
  final PlayFormat? format;

  /// The host's packs once sealed is dealt.
  final List<List<CardData>>? hostPacks;

  /// The host's seat once a draft runs.
  final SeatView? hostSeat;
}

/// A room on the local network: this device deals and passes, the
/// others join by address and code. Seat 0 is the host.
class RoomHost {
  RoomHost({required this.play, required this.hostName, Random? random}) : _random = random ?? Random() {
    code = newRoomCode(_random.nextInt);
  }

  final PlayPool play;
  final String hostName;
  final Random _random;
  late final String code;

  HttpServer? _server;
  final _clients = <int, _Client>{};
  MultiDraft? _draft;
  List<List<List<CardData>>>? _sealed;

  /// Once stopped, nothing is published any more: sockets still close late.
  bool _closed = false;

  final state = ValueNotifier<RoomState>(const RoomState(phase: RoomPhase.lobby, players: []));

  int get port => _server?.port ?? 0;

  /// Listens on [port] (`0` for any free one).
  Future<void> start({int port = 0}) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(_serve, onError: (_) {});
    _publishPlayers();
  }

  /// The addresses others may reach this device at, IPv4 on the local
  /// network, as `address:port`.
  Future<List<String>> addresses() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    return [for (final i in interfaces) for (final a in i.addresses) '${a.address}:$port'];
  }

  Future<void> _serve(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _Client? client;
    socket.listen((data) {
      final message = decodeMessage(data);
      if (message == null) return;
      switch (message['type']) {
        case 'join':
          if (client != null) return;
          if (message['code'] != code) {
            socket.add(encodeMessage('error', {'message': 'code'}));
            socket.close();
            return;
          }
          if (state.value.phase != RoomPhase.lobby) {
            socket.add(encodeMessage('error', {'message': 'started'}));
            socket.close();
            return;
          }
          final seat = _freeSeat();
          client = _Client(seat, '${message['name'] ?? 'Player $seat'}', socket);
          _clients[seat] = client!;
          socket.add(encodeMessage('welcome', {
            'version': protocolVersion,
            'seat': seat,
            'game': play.pool.game.name,
            'pool': play.pool.name,
            'players': [for (final p in players) playerToJson(p)],
          }));
          _publishPlayers();
        case 'pick':
          if (client case final c?) pick(c.seat, '${message['card']}');
      }
    }, onDone: () {
      if (client case final c?) {
        c.connected = false;
        _publishPlayers();
      }
    }, onError: (_) {});
  }

  int _freeSeat() {
    var seat = 1;
    while (_clients.containsKey(seat)) {
      seat++;
    }
    return seat;
  }

  /// Everyone seated: the host, then the people, then the bots of a draft.
  List<RoomPlayer> get players => [
        (seat: 0, name: hostName, bot: false, connected: true),
        for (final c in _clients.values) (seat: c.seat, name: c.name, bot: false, connected: c.connected),
        if (_draft case final draft?)
          for (var seat = 0; seat < draft.seats; seat++)
            if (!draft.humans.contains(seat)) (seat: seat, name: 'Bot $seat', bot: true, connected: true),
      ]..sort((a, b) => a.seat - b.seat);

  void _publishPlayers() {
    final list = players;
    _broadcast(encodeMessage('players', {'players': [for (final p in list) playerToJson(p)]}));
    _set(players: list);
  }

  void _set({RoomPhase? phase, List<RoomPlayer>? players, PlayFormat? format, List<List<CardData>>? hostPacks, SeatView? hostSeat}) {
    if (_closed) return;
    final s = state.value;
    state.value = RoomState(
      phase: phase ?? s.phase,
      players: players ?? s.players,
      format: format ?? s.format,
      hostPacks: hostPacks ?? s.hostPacks,
      hostSeat: hostSeat ?? s.hostSeat,
    );
  }

  /// Deals [format] to everyone seated and sends each their packs.
  void startSealed(PlayFormat format) {
    final seats = [0, ..._clients.keys];
    final sources = <String, PackSource>{};
    final dealt = <List<List<CardData>>>[];
    for (final _ in seats) {
      dealt.add([
        for (final round in format.rounds)
          (sources[round.booster] ??= play.boosterPlay(round.booster)!.newSource()).nextPack(),
      ]);
    }
    _sealed = dealt;
    for (final (i, seat) in seats.indexed) {
      if (seat == 0) continue;
      _clients[seat]?.send(encodeMessage('sealed', {
        'packs': [for (final pack in dealt[i]) cardsToJson(pack)],
      }));
    }
    _set(phase: RoomPhase.sealed, format: format, hostPacks: dealt.first);
  }

  /// Starts a draft of [format] with [seats] seats: the people, bots for
  /// the rest.
  void startDraft(PlayFormat format, {required int seats}) {
    final humans = {0, ..._clients.keys};
    final total = max(seats, humans.length);
    final sources = <String, PackSource>{};
    _draft = MultiDraft(
      [
        for (final round in format.rounds)
          DraftRound(
            sources[round.booster] ??= play.boosterPlay(round.booster)!.newSource(),
            picks: round.picks,
            burn: round.burn,
          ),
      ],
      seats: total,
      humans: humans,
      random: _random,
    );
    _set(phase: RoomPhase.draft, format: format);
    _publishPlayers();
    _publishDraft();
  }

  /// [seat] picks [cardId]; the host's own seat is 0.
  void pick(int seat, String cardId) {
    final draft = _draft;
    if (draft == null || !draft.pickFor(seat, cardId)) return;
    _publishDraft();
  }

  SeatView seatView(int seat) {
    final draft = _draft!;
    final names = {for (final p in players) p.seat: p.name};
    return SeatView(
      round: min(draft.round, draft.rounds.length),
      rounds: draft.rounds.length,
      pick: draft.pick,
      phase: draft.isFinished ? DraftPhase.pick : draft.phaseFor(seat),
      remaining: draft.remainingFor(seat),
      pack: draft.packFor(seat),
      pool: draft.pools[seat],
      waiting: [for (final s in draft.waitingOn) if (s != seat) names[s] ?? 'Player $s'],
      finished: draft.isFinished,
    );
  }

  void _publishDraft() {
    for (final c in _clients.values) {
      c.send(encodeMessage('draft', seatView(c.seat).toJson()));
    }
    _set(hostSeat: seatView(0));
  }

  void _broadcast(String message) {
    if (_closed) return;
    for (final c in _clients.values) {
      c.send(message);
    }
  }

  /// Closes the room: every player is told and dropped.
  Future<void> stop() async {
    if (_closed) return;
    _closed = true;
    for (final c in _clients.values) {
      await c.socket.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    state.dispose();
  }

  /// The sealed packs dealt to everyone, by seat order (tests).
  @visibleForTesting
  List<List<List<CardData>>>? get sealedDeals => _sealed;
}

class _Client {
  _Client(this.seat, this.name, this.socket);

  final int seat;
  final String name;
  final WebSocket socket;
  bool connected = true;

  void send(String message) {
    if (connected) socket.add(message);
  }
}
