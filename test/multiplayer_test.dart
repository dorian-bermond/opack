import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/draft/domain/draft_session.dart';
import 'package:opack/features/multiplayer/data/room_client.dart';
import 'package:opack/features/multiplayer/data/room_host.dart';
import 'package:opack/features/multiplayer/domain/multi_draft.dart';
import 'package:opack/features/multiplayer/domain/protocol.dart';
import 'package:opack/features/packs/domain/pack_source.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';

/// Packs of [size] numbered cards, each pack its own numbers.
class _Packs implements PackSource {
  _Packs(this.size);
  final int size;
  int _dealt = 0;

  @override
  List<CardData> nextPack() {
    final n = _dealt++;
    return [
      for (var i = 0; i < size; i++)
        CardData(id: 'P$n-$i', names: {'en': 'Card $n-$i'}, rarity: i == 0 ? Rarity.rare : Rarity.common),
    ];
  }
}

Future<void> until(bool Function() ready, {Duration limit = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(limit);
  while (!ready()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('people pick at their own pace; the pass moves once all are done, bots filling the rest', () {
    final draft = MultiDraft([DraftRound(_Packs(3))], seats: 4, humans: {0, 2}, random: Random(1));
    expect(draft.waitingOn, {0, 2});
    expect(draft.packFor(0).map((c) => c.id), ['P0-0', 'P0-1', 'P0-2']);
    expect(draft.pickFor(0, 'P0-1'), isTrue);
    expect(draft.doneFor(0), isTrue);
    expect(draft.pickFor(0, 'P0-2'), isFalse, reason: 'done for the pass');
    expect(draft.waitingOn, {2}, reason: 'the pack waits for seat 2');
    expect(draft.pick, 1);
    expect(draft.pickFor(2, 'nope'), isFalse, reason: 'not in hand');
    expect(draft.pickFor(2, 'P2-0'), isTrue);
    expect(draft.pick, 2, reason: 'everyone done: the packs passed');
    expect(draft.pools[1].single.id, 'P1-0', reason: 'the bot took the rare');
    expect(draft.pools[3].single.id, 'P3-0');
    // Round one passes left: seat 0 now holds what seat 3 had.
    expect(draft.packFor(0).map((c) => c.id), ['P3-1', 'P3-2']);
    draft.pickFor(0, 'P3-1');
    draft.pickFor(2, 'P1-1');
    draft.pickFor(0, draft.packFor(0).single.id);
    draft.pickFor(2, draft.packFor(2).single.id);
    expect(draft.isFinished, isTrue);
    expect(draft.pools.map((p) => p.length), [3, 3, 3, 3]);
  });

  test('messages and seat views go through JSON and back', () {
    const card = CardData(id: 'X-1', names: {'en': 'Alpha'}, rarity: Rarity.rare, passcode: '42');
    final view = SeatView(
      round: 1, rounds: 3, pick: 2, phase: DraftPhase.pick, remaining: 1,
      pack: [card.asFoil()], pool: const [card], waiting: const ['Bob'], finished: false,
    );
    final back = SeatView.fromJson(decodeMessage(encodeMessage('draft', view.toJson()))!);
    expect(back.pack.single.foil, isTrue);
    expect(back.pack.single.passcode, '42');
    expect(back.pool.single.id, 'X-1');
    expect(back.waiting, ['Bob']);
    expect(decodeMessage('not json'), isNull);
    expect(decodeMessage('{"x":1}'), isNull, reason: 'no type');
    expect(newRoomCode((n) => 0), 'AAAA');
    final player = playerFromJson(playerToJson((seat: 2, name: 'Bob', bot: false, connected: true)));
    expect(player.name, 'Bob');
  });

  test('a host deals sealed and runs a draft with a player over the loopback', () async {
    final cards = [for (var i = 0; i < 60; i++) CardData(id: 'C$i', names: {'en': 'C$i'}, rarity: Rarity.common)];
    var pool = Pool.empty(Game.mtg, name: 'Room pool').withSource(CardsSource(cards), cards: cards);
    pool = pool.copyWith(slots: const [PackSlot(3, [SlotOption('rarity:common')])]);
    final play = PlayPool.resolve(pool, sets: const {}, cubes: const {});
    final sealed = PlayFormat(id: 's', name: 'Sealed', kind: FormatKind.sealed, rounds: const [FormatRound('Booster'), FormatRound('Booster')]);
    final draft = PlayFormat(id: 'd', name: 'Draft', kind: FormatKind.draft, rounds: const [FormatRound('Booster')], seats: 4);

    final host = RoomHost(play: play, hostName: 'Host', random: Random(3));
    await host.start();
    expect(host.port, greaterThan(0));
    final client = RoomClient();
    await client.connect('127.0.0.1:${host.port}', name: 'Bob', code: host.code);
    await until(() => client.state.value.status == ClientStatus.lobby);
    expect(client.state.value.seat, 1);
    expect(client.state.value.poolName, 'Room pool');
    await until(() => host.state.value.players.length == 2);
    expect(host.state.value.players.map((p) => p.name), ['Host', 'Bob']);

    // A wrong code is refused.
    final intruder = RoomClient();
    await intruder.connect('127.0.0.1:${host.port}', name: 'Eve', code: 'ZZZZ');
    await until(() => intruder.state.value.status == ClientStatus.error);
    expect(intruder.state.value.error, 'code');
    await intruder.close();

    // Sealed: everyone gets their own packs.
    host.startSealed(sealed);
    await until(() => client.state.value.status == ClientStatus.sealed);
    expect(client.state.value.packs!.length, 2);
    expect(client.state.value.packs!.first.length, 3);
    expect(host.state.value.hostPacks!.length, 2);
    final hostIds = {for (final p in host.state.value.hostPacks!) for (final c in p) c.id};
    final bobIds = {for (final p in client.state.value.packs!) for (final c in p) c.id};
    expect(hostIds.intersection(bobIds), isEmpty, reason: 'different cards for each');

    // A draft with two bots: picks go through the host.
    host.startDraft(draft, seats: 4);
    await until(() => client.state.value.status == ClientStatus.draft);
    expect(host.state.value.players.where((p) => p.bot).length, 2);
    final bob = client.state.value.draft!;
    expect(bob.pack.length, 3);
    expect(bob.remaining, 1);
    client.pick(bob.pack.first.id);
    await until(() => client.state.value.draft!.remaining == 0);
    expect(client.state.value.draft!.waiting, ['Host'], reason: 'the pass waits on the host');
    host.pick(0, host.state.value.hostSeat!.pack.first.id);
    await until(() => client.state.value.draft!.pick == 2);
    expect(client.state.value.draft!.pool.length, 1);
    expect(host.state.value.hostSeat!.pick, 2);

    await host.stop();
    await until(() => client.state.value.status == ClientStatus.closed);
    await client.close();
  });
}
