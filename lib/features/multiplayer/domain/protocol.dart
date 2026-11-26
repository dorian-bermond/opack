import 'dart:convert';

import '../../catalog/domain/models.dart';
import '../../draft/domain/draft_session.dart';

/// What the host and the players say to each other, as JSON lines over a
/// WebSocket. Every message is a map with a `type`.
///
/// Player to host: `join` {name, code}, `pick` {card}.
/// Host to player: `welcome` {seat, game, pool, players}, `players`
/// {players}, `sealed` {packs}, `draft` {seat view}, `error` {message}.
const protocolVersion = 1;

/// One seat of the room: a person by name, a bot, and whether the person
/// is connected.
typedef RoomPlayer = ({int seat, String name, bool bot, bool connected});

Map<String, Object?> playerToJson(RoomPlayer p) =>
    {'seat': p.seat, 'name': p.name, 'bot': p.bot, 'connected': p.connected};

RoomPlayer playerFromJson(Map<String, dynamic> json) => (
      seat: json['seat'] as int,
      name: json['name'] as String,
      bot: json['bot'] as bool? ?? false,
      connected: json['connected'] as bool? ?? true,
    );

/// What a seat sees of a draft: the pack in hand, the pool so far, where
/// the draft is and whom it waits on.
class SeatView {
  const SeatView({
    required this.round,
    required this.rounds,
    required this.pick,
    required this.phase,
    required this.remaining,
    required this.pack,
    required this.pool,
    required this.waiting,
    required this.finished,
  });

  factory SeatView.fromJson(Map<String, dynamic> json) => SeatView(
        round: json['round'] as int,
        rounds: json['rounds'] as int,
        pick: json['pick'] as int,
        phase: DraftPhase.values.byName(json['phase'] as String),
        remaining: json['remaining'] as int,
        pack: cardsFromJson(json['pack']),
        pool: cardsFromJson(json['pool']),
        waiting: (json['waiting'] as List? ?? const []).cast<String>(),
        finished: json['finished'] as bool? ?? false,
      );

  final int round;
  final int rounds;
  final int pick;
  final DraftPhase phase;

  /// Cards still to pick or burn this pass; `0` while waiting on others.
  final int remaining;
  final List<CardData> pack;
  final List<CardData> pool;

  /// The names of the people the pass waits on (oneself left out).
  final List<String> waiting;
  final bool finished;

  Map<String, Object?> toJson() => {
        'round': round,
        'rounds': rounds,
        'pick': pick,
        'phase': phase.name,
        'remaining': remaining,
        'pack': cardsToJson(pack),
        'pool': cardsToJson(pool),
        'waiting': waiting,
        'finished': finished,
      };
}

List<Map<String, Object?>> cardsToJson(List<CardData> cards) =>
    [for (final c in cards) {...c.toJson(), if (c.foil) 'foil': true}];

List<CardData> cardsFromJson(Object? json) => [
      for (final c in (json as List? ?? const []).cast<Map<String, dynamic>>())
        c['foil'] == true ? CardData.fromJson(c).asFoil() : CardData.fromJson(c),
    ];

String encodeMessage(String type, Map<String, Object?> body) => jsonEncode({'type': type, ...body});

/// A message read back; `null` when it is not one.
Map<String, dynamic>? decodeMessage(Object? data) {
  if (data is! String) return null;
  try {
    final json = jsonDecode(data);
    return json is Map<String, dynamic> && json['type'] is String ? json : null;
  } on FormatException {
    return null;
  }
}

/// A room code: four letters easy to read out.
String newRoomCode(int Function(int) nextInt) {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  return [for (var i = 0; i < 4; i++) letters[nextInt(letters.length)]].join();
}
